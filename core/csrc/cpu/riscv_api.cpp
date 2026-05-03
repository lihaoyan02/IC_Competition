#include <common.h>
#include <core.h>

VerilatedContext* contextp = NULL;
#ifndef CONFIG_TARGET_SOC
Vtop* top = NULL;
#else
VysyxSoCFull* top = NULL;
#endif
#ifdef CONFIG_TRACE_WAVE
VerilatedVcdC* tfp = NULL;
#endif 

#ifndef CONFIG_TARGET_SOC
char WBUscope[] = "TOP.top.u_WBU";
char gprscope[] = "TOP.top.u_regfile";
#else
char IFUscope[] = "TOP.ysyxSoCFull.asic.cpu.cpu.u_core.u_IFU";
char gprscope[] = "TOP.ysyxSoCFull.asic.cpu.cpu.u_core.u_gpr";
#endif

uint32_t core_read_pc() {
	const svScope scope = svGetScopeFromName(WBUscope);
	assert(scope); 
	svSetScope(scope);
	return read_pc(); 
}

uint32_t core_read_reg(uint32_t idx) {
	assert(idx<32);
	const svScope scope = svGetScopeFromName(gprscope);
	assert(scope); 
	svSetScope(scope);
	return read_reg(idx);
}

uint32_t core_read_state() {
	const svScope scope = svGetScopeFromName(WBUscope);
	assert(scope); 
	svSetScope(scope);
	return read_state();
}