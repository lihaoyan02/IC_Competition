#ifndef __NPC_MEMORY_H__
#define __NPC_MEMORY_H__

#include <common.h>

#define MEM_MAX 0x8000000 
#define MEM_BASE 0x80000000 

#ifdef CONFIG_TARGET_SOC
#define MROM_BASE 0x20000000
#endif

static bool in_mem(uint32_t addr) { 
	return addr - MEM_BASE < MEM_MAX; 
}
int read_inst(int addr);
extern "C" int pmem_read(int raddr);

extern "C" void pmem_write(int waddr, int wdata, char wmask);

long load_mem(const char* img);

uint8_t *memory_export(uint32_t addr);

#endif
