#include <memory.h>
#include <cpu.h>
#include <reg.h>
#include <readline/readline.h>
#include <readline/history.h>

uint32_t expr(char *e, bool *success);

static int is_batch_mode = false;

void init_regex();
void init_wp_pool();
void set_new_wp(char *e);
void delete_wp(int N);
void print_wp_info();

void print_funct_info();

static char* rl_gets() {
	static char *line_read = NULL;

	if (line_read) {
		free(line_read);
		line_read = NULL;
	}

	line_read = readline("(npc) ");

	if (line_read && *line_read) {
		add_history(line_read);
	}

	return line_read;
}

static int cmd_q(char *args) {
	npc_state.state = NPC_QUIT;
	return -1; 
}

/*--------single execution------------*/
static int cmd_si(char *args) {
	char *N_str = strtok(NULL, " ");
	int N_num = 1;
	if (N_str != NULL) {
		N_num = atoi(N_str);
	}
	cpu_exec(N_num);
	return 0;
}

/*---------print program status------------*/
static int cmd_info(char *args) {
	char *arg = strtok(NULL," ");
	if (arg == NULL) {
		printf("An argument r or w is required\n");
	} else if(strcmp(arg, "r") == 0) {
		reg_display();
	} else if (strcmp(arg, "w") == 0) {
		print_wp_info();
	} else if (strcmp(arg, "f") == 0) {
		print_funct_info();
	} else {
		printf("Invalid argument\n");
	}
	return 0;
}

/*---------scan memeory---------*/
static int cmd_x(char *args) {
	char *N_str = strtok(NULL," ");
	char *expression = strtok(NULL," ");
	if ((N_str==NULL) || (expression==NULL)) {
		printf("require 2 arguments N and EXPR\n");
	} else {
		unsigned int N_num = (unsigned int)atoi(N_str);
		bool success = true;
		uint32_t result = expr(expression, &success);
		if(success) {
			for(uint32_t i = 0; i != N_num; i++) {
				printf("[%d] 0x%08X : 0x%08X\n", i, ((i*4+result) & ~0x3u), pmem_read(i*4+result));
			}
		}else {
			printf("parse expression fail\n");
		}
	}
	return 0;
}

/*---------print expression---------*/
static int cmd_p(char *args) {
	bool success = true;
	bool *ptr_success = &success;
	uint32_t result = expr(args, ptr_success);
	if(success == false) {
		printf("try again\n");
	} else {
		 printf("%u (%x)\n", result, result);
	}
	return 0;
}

/*--------set watchpoint---------*/
static int cmd_w(char *args) {
	set_new_wp(args);
	return 0;
}

/*--------delete watchpoint---------*/
static int cmd_d(char *args) {
	char *N_str = strtok(NULL," ");
	if (N_str==NULL) {
		printf("require an arguments N\n");
	}else {
		int N_num = (int)atoi(N_str);
		delete_wp(N_num);
	}
	return 0;
}

/*--------tracer info-------*/ 
void iringbuf_print();
void ftrace_print();
static int cmd_t(char *args) {
	char *arg = strtok(NULL," ");
	if (arg == NULL) {
		printf("An argument i or f is required\n");
	} else if(strcmp(arg, "i") == 0) {
		iringbuf_print();
	} else if (strcmp(arg, "f") == 0) {
		ftrace_print();
	} else {
		printf("Invalid argument\n");
	}
	return 0;
}

void sdb_set_batch_mode() {
	is_batch_mode = true;
}

static int cmd_c(char *args) {
	cpu_exec(-1);
	return 0;
}

static int cmd_help(char *args); 

static struct {
	const char *name;
	const char *description;
	int (*handler) (char *);
} cmd_table [] = {
	{ "help", "Display information about all supported commands", cmd_help },
	{ "c", "Continue the execution of the program", cmd_c },
	{ "q", "Exit npc", cmd_q },
	{ "si", "Execute N instruction(s) and stop, default N = 1", cmd_si },
	{ "info", "Print register status(r), print watch point messages(w)", cmd_info },
	{ "x", "Scan the memory from the given expression in heximal for N times of 4 bytes", cmd_x },
	{ "p", "Print the expression's result", cmd_p },
	{ "w", "Set a watchpoint for given expression", cmd_w },
	{ "d", "Delete a watchpoint for given watchpoint number N", cmd_d },
	{ "t", "Print tracer info itrace(i) ftrace(f)", cmd_t },

};

#define NR_CMD ARRLEN(cmd_table)

static int cmd_help(char *args) {
	/* extract the first argument */
	char *arg = strtok(NULL, " ");
	int i;

	if (arg == NULL) {
		/* no argument given */
		for (i = 0; i < NR_CMD; i ++) {
			printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
		}
	}
	else {
		for (i = 0; i < NR_CMD; i ++) {
			if (strcmp(arg, cmd_table[i].name) == 0) {
				printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
				return 0;
			}
		}
		printf("Unknown command '%s'\n", arg);
	}
	return 0;
}

void sdb_mainloop() {
	if (is_batch_mode) {
		cmd_c(NULL);
		return;
	}

	for (char *str; (str = rl_gets()) != NULL; ) {
		char *str_end = str + strlen(str);

		/* extract the first token as the command */
		char *cmd = strtok(str, " ");
		if (cmd == NULL) {continue; }

		/* treat the remaining string as the arguments,
		 * which may need further parsing
		 */
		char *args = cmd + strlen(cmd) + 1;
		if (args >= str_end) {
			args = NULL;
		}

		int i;
		for (i = 0; i < NR_CMD; i++) {
			if (strcmp(cmd, cmd_table[i].name) == 0) {
				if(cmd_table[i].handler(args) < 0) { return; }
				break;
			}
		}

		if (i == NR_CMD) { printf("Unknow command '%s'\n", cmd); }
	}
}

void init_sdb() {
	/* Compile the regular expressions. */
	init_regex();

	/* Initialize the watchpoint pool. */
	init_wp_pool();
}
