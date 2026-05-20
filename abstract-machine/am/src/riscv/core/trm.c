#include <am.h>
#include <klib-macros.h>
#include <riscv/riscv.h>

extern char _heap_start;
int main(const char *args);

extern char _pmem_start;
#define PMEM_SIZE (128 * 1024 * 1024)
#define PMEM_END  ((uintptr_t)&_pmem_start + PMEM_SIZE)

Area heap = RANGE(&_heap_start, PMEM_END);
static const char mainargs[MAINARGS_MAX_LEN] = TOSTRING(MAINARGS_PLACEHOLDER); // defined in CFLAGS

void putch(char ch) {
	 outb(0x10000000, ch);
	 //outb(0xa00003f8, ch);
}

void halt(int code) {
	asm volatile("mv a0, %0; ebreak" : :"r"(code));
	while(1);
}

//#include <stdio.h>
void _trm_init() {
	/*
	uint32_t marchid;
	uint32_t mvendorid;
	asm volatile("csrr %0, marchid":"=r" (marchid));
	asm volatile("csrr %0, mvendorid":"=r" (mvendorid));
	char *arch_str = (char*)&mvendorid;
	printf("%c%c%c%c-%d\n",arch_str[3],arch_str[2],arch_str[1],arch_str[0],marchid);
	*/
  int ret = main(mainargs);
  halt(ret);
}
