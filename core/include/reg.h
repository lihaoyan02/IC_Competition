
#ifndef __RISCV_REG_H__
#define __RISCV_REG_H__

#include <common.h>

typedef struct {
	uint32_t gpr[32];
	uint32_t pc;
} CPU_state;

extern CPU_state cpu;

static inline int check_reg_idx(int idx) {
	assert(idx >= 0 && idx < 32);
	return idx;
}

static inline const char* reg_name(int idx) {
	extern const char* regs[];
	return regs[check_reg_idx(idx)];
}

void reg_display();
const char *reg_idx2str(int idx);

uint32_t reg_str2val(const char *s, bool *success);

void update_reg_state(int pc);

#endif
