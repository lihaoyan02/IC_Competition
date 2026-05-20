#include <am.h>
#include <riscv/riscv.h>

void __am_timer_init() {
}

void __am_timer_uptime(AM_TIMER_UPTIME_T *uptime) {
	// uint32_t h_us = inl(0xa0000048+4);
	// uint32_t l_us = inl(0xa0000048);
  // uptime->us = (((uint64_t)h_us)<<32) | ((uint64_t)l_us);
  uint32_t h_us = inl(0x200bff8+4);
	uint32_t l_us = inl(0x200bff8);
  uptime->us = (((uint64_t)h_us)<<32) | ((uint64_t)l_us)/8;
}

void __am_timer_rtc(AM_TIMER_RTC_T *rtc) {
  rtc->second = 0;
  rtc->minute = 0;
  rtc->hour   = 0;
  rtc->day    = 0;
  rtc->month  = 0;
  rtc->year   = 1900;
}
