#include <common.h> 
#include <SDL2/SDL.h>

#define TIMER_HZ 60

uint64_t get_time();

void device_update() { 
	static uint64_t last = 0;
	uint64_t now = get_time();
	if (now - last < 1000000 / TIMER_HZ) { 
		return;
	}
	last = now;

}

void init_device() { 
}
