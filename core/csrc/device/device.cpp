#include <common.h> 
#include <SDL2/SDL.h>

#define TIMER_HZ 60

void init_vga();
void vga_update_screen();
uint64_t get_time();

void device_update() { 
	static uint64_t last = 0;
	uint64_t now = get_time();
	if (now - last < 1000000 / TIMER_HZ) { 
		return;
	}
	last = now;

	IFDEF(CONFIG_HAS_VGA, vga_update_screen()); 
#ifdef CONFIG_HAS_VGA
	SDL_Event event;
	while (SDL_PollEvent(&event)) {
		switch (event.type) {
			case SDL_QUIT:
				npc_state.state = NPC_QUIT;
				break;
			default: break;
		}
	}
#endif
}

void init_device() { 
	IFDEF(CONFIG_HAS_VGA, init_vga());
}
