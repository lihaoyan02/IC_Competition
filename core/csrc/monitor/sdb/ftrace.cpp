#include <common.h>
#include <decode.h>
#include <elf.h>

enum inst_type{
	TYPE_OTHER, TYPE_CALL, TYPE_RET
};

typedef struct func_pool {
	struct func_pool *next;
	
	char name[32];
	uint32_t addr;
	uint32_t size;
} FPOOL;

#define FRING_SIZE 50
struct fbuf {
	int num;
	char pcbuf[16];
	char message[128];
	enum inst_type type;
} fringbuf[FRING_SIZE];

static int fringbuf_ptr = 0;
static int stack_ptr = 0;
static FPOOL *head = NULL;

unsigned char *elf_buffer;



static void new_fp(char* name, uint32_t addr, uint32_t size) {
	FPOOL* new_func = (FPOOL *)malloc(sizeof(FPOOL));
	sprintf(new_func->name,"%s",name);
	new_func->addr = addr;
	new_func->size = size;	
	new_func->next = head;
	head = new_func;
}

void free_fp() {
	while(head != NULL) {
		FPOOL *temp_to_free = head;
		head = temp_to_free->next;
		free(temp_to_free);
	}
}
		
static FPOOL* pc_compare(uint32_t pc) {
	for( FPOOL* current = head; current != NULL; current = current->next) {
		if( pc >= current->addr && pc < (current->addr + current->size)) return current;
	}
	return NULL;
}

static bool pc_compare_off(uint32_t pc) {
	for( FPOOL* current = head; current != NULL; current = current->next) {
		if( pc == current->addr) return true;
	}
	return false;
}


static void fringbuf_push(enum inst_type type, uint32_t pc, char* logbuf, int stack_num) {
	fringbuf[fringbuf_ptr].type = type;
	fringbuf[fringbuf_ptr].num = stack_num;
	memcpy(fringbuf[fringbuf_ptr].message, logbuf, 128);
	sprintf(fringbuf[fringbuf_ptr].pcbuf,"0x%08x:",pc);
	if(++fringbuf_ptr >= FRING_SIZE) {
		fringbuf_ptr = 0;
	}
}

void print_funct_info() {
	for( FPOOL* current = head; current != NULL; current = current->next) {
		printf("%s\n",current->name);
	}
	printf("\n");
}

void ftrace_print() {
	for(int i=0; i<FRING_SIZE; i++) {
		int real_ptr = (fringbuf_ptr+i < FRING_SIZE) ? fringbuf_ptr + i : fringbuf_ptr + i - FRING_SIZE;
		if(fringbuf[real_ptr].message[0] != '\0') {
			printf("%s ",fringbuf[real_ptr].pcbuf);
			for(int j=0; j<fringbuf[real_ptr].num; j++) {
				printf(" ");
			}
			printf("%s\n",fringbuf[real_ptr].message);
		}
	}
}

void ftrace_rcd(Decode *s) {
	if(head == NULL) return;
	uint32_t inst = s->inst;
	if ((inst & 0b1110111) == 0b1100111 ) {
		// jal and jalr
		FPOOL* next_fp = pc_compare(s->dnpc);
		FPOOL* current_fp = pc_compare(s->pc);
		char logbuf[128];
		memset(logbuf, '\0', 128);
		if(next_fp == NULL) {
			sprintf(logbuf, "call/ret [???]");
			fringbuf_push(TYPE_OTHER, s->pc, logbuf, stack_ptr);
		} else {
			if (((inst>>7) &0b11111) != 0b00000 && pc_compare_off(s->dnpc)) {
				sprintf(logbuf, "call [%s@0x%08x]",next_fp->name, next_fp->addr);
				fringbuf_push(TYPE_CALL, s->pc, logbuf, stack_ptr++);
			} else if((inst & 0b1111111) == 0b1100111 //jalr
					&& ((inst>>7) & 0b11111) == 0b00000 
					&& next_fp->addr != s->dnpc
					&& next_fp->name != current_fp->name){
				sprintf(logbuf, "ret [%s]",current_fp->name);
				if(stack_ptr == 0) panic("return before call\n");//stack_ptr = 1;//panic("return before call\n");
				fringbuf_push(TYPE_RET, s->pc, logbuf, --stack_ptr);
			}
		}
	}
}


void init_ftrace(unsigned char *buffer) {
	if (!buffer) {
		return;
	}

	Elf32_Ehdr *ehdr = (Elf32_Ehdr *) buffer;

	if (memcmp(ehdr->e_ident, ELFMAG, SELFMAG) !=0) {
		free(buffer);
		printf("no valid elf\n");
		assert(memcmp(ehdr->e_ident, ELFMAG, SELFMAG) ==0);
	}

	// section header
	Elf32_Shdr *shdr = (Elf32_Shdr *)(buffer + ehdr->e_shoff);

	for (int i=0; i < ehdr->e_shnum; i++) {
		if (shdr[i].sh_type != SHT_SYMTAB && shdr[i].sh_type != SHT_DYNSYM) {
			continue;
		}

		Elf32_Sym *symtab = (Elf32_Sym *)(buffer + shdr[i].sh_offset);
		int sym_count = shdr[i].sh_size / shdr[i].sh_entsize;
		// str tab
		int strtab_index = shdr[i].sh_link;
		Elf32_Shdr *str_shdr = (Elf32_Shdr *)(buffer + ehdr->e_shoff + strtab_index * ehdr->e_shentsize);
		char * strtab = (char *)(buffer + str_shdr->sh_offset);

		for (int j = 0; j<sym_count; j++) {
			Elf32_Sym *sym = &symtab[j];

			unsigned char type = ELF32_ST_TYPE(sym->st_info);

			if(type == STT_FUNC && sym->st_shndx != SHN_UNDEF) {
				char *sym_name = strtab + sym->st_name;
				if (sym->st_name != 0) {
					new_fp(sym_name, sym->st_value, sym->st_size);
				}
			}
		}
	}
	free(buffer);
}
	
