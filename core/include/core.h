#ifndef __CORE_H__
#define __CORE_H__

#include "generated/autoconf.h"
#include <verilated.h>

#ifndef CONFIG_TARGET_SOC
#include <Vtop.h>
#include <Vtop__Dpi.h> 
extern VerilatedContext* contextp;
extern Vtop* top;

#else
#include <VysyxSoCFull.h>
#include <VysyxSoCFull__Dpi.h> 
extern VerilatedContext* contextp;
extern VysyxSoCFull* top;

#endif

#ifdef CONFIG_TRACE_WAVE
#include "verilated_vcd_c.h"
extern VerilatedVcdC* tfp; 
#endif


uint32_t core_read_pc();

uint32_t core_read_reg(uint32_t idx);

uint32_t core_read_state();

#endif
