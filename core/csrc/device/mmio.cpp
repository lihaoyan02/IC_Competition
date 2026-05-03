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

uint32_t vga_ctl_read(int idx);
uint32_t screen_size();
void vga_mem_write(uint32_t addr, uint8_t data_byte);
void vga_ctl_write(int idx, uint32_t data);

uint32_t mmio_read(int addr) {
	if( addr == 0xa0000048) {
		return rtc_port[0];
	} else if ( addr == 0xa0000048+4) {
		rtc_port_update();
		return rtc_port[1];
	}else if (addr == 0xa0000100) {
		IFDEF(CONFIG_HAS_VGA, return vga_ctl_read(0));
	}else if (addr == 0xa0000100+4) {
		IFDEF(CONFIG_HAS_VGA, return vga_ctl_read(1));
	}
	panic("illegal access for pmem, 0x%08x\n",addr);
	assert(0);
}

void mmio_write(uint32_t addr, uint32_t data, char mask) {
	//if ( addr == 0x10000000){
	if ( addr == 0xa00003f8){
		panic("illegal access for pmem, 0x%08x\n",addr);
		//putc((uint8_t)data,stderr);
		return;
	} else if (addr == 0xa0000100 && mask == 0b1111) {
		IFDEF(CONFIG_HAS_VGA, vga_ctl_write(0, data); return);
	} else if (addr == 0xa0000100+4 && mask == 0b1111) {
		IFDEF(CONFIG_HAS_VGA, vga_ctl_write(1, data); return);
	} else if (addr >= 0xa1000000 && addr < 0xa1000000 + screen_size()) {
			uint32_t paddr =addr-0xa1000000;
			if (mask & 0x1) {
				IFDEF(CONFIG_HAS_VGA, vga_mem_write(paddr, (uint8_t)(data & 0xff)));
			}
			if (mask & 0x2) {
				IFDEF(CONFIG_HAS_VGA, vga_mem_write(paddr+1, (uint8_t)(data>>8 & 0xff)));
			}
			if (mask & 0x4) {
				IFDEF(CONFIG_HAS_VGA, vga_mem_write(paddr+2, (uint8_t)(data>>16 & 0xff)));
			}
			if (mask & 0x8) {
				IFDEF(CONFIG_HAS_VGA, vga_mem_write(paddr+3, (uint8_t)(data>>24 & 0xff)));
			}
			IFDEF(CONFIG_HAS_VGA, return);
	} 
	panic("illegal access for pmem, mem=0x%08x\n",addr);
	assert(0);
	
}
