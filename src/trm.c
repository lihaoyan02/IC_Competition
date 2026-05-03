
int main();

void halt(int code) {
	asm volatile("mv a0, %0; ebreak" : :"r"(code));
	while(1);
}

void _trm_init() {
  int ret = main();
  halt(ret);
}