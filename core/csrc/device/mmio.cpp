#include <chrono> 
#include <common.h>

static uint32_t rtc_port[2];
static uint64_t boot_time = 0;

static uint64_t get_time_internal() {
	using namespace std::chrono; 
	return duration_cast<microseconds>(
			steady_clock::now().time_since_epoch()
			).count();
}

uint64_t get_time() {
	if (boot_time == 0) boot_time = get_time_internal();
	uint64_t now = get_time_internal();
	return now - boot_time;
}

static void rtc_port_update() {
	uint64_t us = get_time();
	rtc_port[0] = (uint32_t)us;
	rtc_port[1] = us >> 32;
}

uint32_t screen_size();

uint32_t mmio_read(int addr) {
	if( addr == 0xa0000048) {
		return rtc_port[0];
	} else if ( addr == 0xa0000048+4) {
		rtc_port_update();
		return rtc_port[1];
	}
	panic("illegal access for pmem, 0x%08x\n",addr);
	assert(0);
}

void mmio_write(uint32_t addr, uint32_t data, char mask) {
	if ( addr == 0x10000000){
		putc((uint8_t)data,stderr);
		return;
	}
	panic("illegal access for pmem, mem=0x%08x\n",addr);
	assert(0);
	
}
