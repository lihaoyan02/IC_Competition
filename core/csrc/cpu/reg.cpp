#include <core.h>
#include <reg.h>

CPU_state cpu = {};

const char *regs[] = {
	"$0", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
	"s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
	"a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
	"s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
};

const char *reg_idx2str(int idx) {
	return reg_name(idx);
}


void reg_display() {
	for(int i=0; i < 32; i++) {
		printf("%s = %x\t", reg_name(i), core_read_reg(i));
	}
	printf("\n");
}

uint32_t reg_str2val(const char *s, bool *success) {
	if(strcmp("pc", s)==0) {
		*success = true;
		return core_read_pc();
	}
	for(int i=0; i<32; i++) {
		if (strcmp(reg_name(i), s) == 0) {
			*success = true;
			return core_read_reg(i);
		}
	}
	*success = false;
	return 0;
}

void update_reg_state(int pc) {
	for(int i=0; i<32; i++) {
		cpu.gpr[i] = core_read_reg(i);
	}
	cpu.pc = pc;
}
