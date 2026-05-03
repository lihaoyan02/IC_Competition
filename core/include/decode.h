#ifndef __CPU_DECODE_H__
#define __CPU_DECODE_H_

#include <common.h>

typedef struct Decode {
	uint32_t pc;
	uint32_t snpc;
	uint32_t dnpc;
	uint32_t inst;
	IFDEF(CONFIG_ITRACE, char logbuf[128]);
} Decode;

#endif
