#include <common.h>

#define SCREEN_W 400
#define SCREEN_H 300


static uint32_t screen_width() {
	return SCREEN_W;
}

static uint32_t screen_height() { 
	return SCREEN_H;
}

uint32_t screen_size() {
	return screen_width() * screen_height() * sizeof(uint32_t);
}

static uint8_t *vmem = NULL;
static uint32_t *vgactl_port_base = NULL;

#ifdef CONFIG_HAS_VGA
#include <SDL2/SDL.h>

static SDL_Renderer *renderer = NULL;
static SDL_Texture *texture = NULL;

static void init_screen() {
	SDL_Window *window = NULL;
	char title[128];
	sprintf(title, "riscv32e-NPC");
	SDL_Init(SDL_INIT_VIDEO);
	SDL_CreateWindowAndRenderer(
			SCREEN_W * 2,
			SCREEN_H * 2,
			0, &window, &renderer);
	SDL_SetWindowTitle(window, title);
	texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
			SDL_TEXTUREACCESS_STATIC, SCREEN_W, SCREEN_H);
	SDL_RenderPresent(renderer);
}

static inline void update_screen() {
	SDL_UpdateTexture(texture, NULL, vmem, SCREEN_W * sizeof(uint32_t));
	SDL_RenderClear(renderer); 
	SDL_RenderCopy(renderer, texture, NULL, NULL);
	SDL_RenderPresent(renderer);
}
#else
static inline void update_screen() {}
#endif

void vga_update_screen() {
	if(vgactl_port_base[1]) {
		update_screen();
		vgactl_port_base[1] = 0;
	}
}

uint32_t vga_ctl_read(int idx) {
	if(idx==0)
		return vgactl_port_base[0];
	else if(idx==1)
		return vgactl_port_base[1];
	else
		assert(0);
}

void vga_ctl_write(int idx, uint32_t data) {
	if(idx==0)
		vgactl_port_base[0] = data;
	else if(idx==1)
		vgactl_port_base[1] = data;
	else
		assert(0);
}

void vga_mem_write(uint32_t addr, uint8_t data_byte) {
	if( addr < screen_size())
		vmem[addr] = data_byte;
	else
		assert(0);
}

void init_vga() { 
	vgactl_port_base = (uint32_t *)malloc(8);
	vgactl_port_base[0] = (screen_width() << 16) | screen_height();
	vmem = (uint8_t *)malloc(screen_size());
	IFDEF(CONFIG_HAS_VGA, init_screen());
	IFDEF(CONFIG_HAS_VGA, memset(vmem, 0, screen_size()));
}
