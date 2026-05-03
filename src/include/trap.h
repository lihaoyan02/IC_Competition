#ifndef __TRAP_H__
#define __TRAP_H__

#include "macro.h"


void halt(int code);

__attribute__((noinline))
void check(bool cond) {
  if (!cond) halt(1);
}

#endif
