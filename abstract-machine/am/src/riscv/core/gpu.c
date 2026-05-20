#include <am.h>
#include <riscv/riscv.h>

#define VGACTL_ADDR 0xa0000100
#define SYNC_ADDR (VGACTL_ADDR + 4)
#define FB_ADDR 0xa1000000 

void __am_gpu_init() {
/*	
	int i;
	int w = inl(VGACTL_ADDR)>>16;
	int h = inw(VGACTL_ADDR);
	uint32_t *fb = (uint32_t *)(uintptr_t)FB_ADDR;
	for (i = 0; i < w * h; i ++) fb[i] = i;
	outl(SYNC_ADDR, 1);
*/	
}

void __am_gpu_config(AM_GPU_CONFIG_T *cfg) {
  *cfg = (AM_GPU_CONFIG_T) {
    .present = true, .has_accel = false,
    .width = inl(VGACTL_ADDR)>>16, .height = inw(VGACTL_ADDR),
    .vmemsz = inl(VGACTL_ADDR)>>16 * inw(VGACTL_ADDR) * sizeof(uint32_t)
  };
}

void __am_gpu_fbdraw(AM_GPU_FBDRAW_T *ctl) {
	uint32_t x = ctl->x;
	uint32_t y = ctl->y;
	uint32_t w = ctl->w;
	uint32_t h = ctl->h;
	uint32_t width = inl(VGACTL_ADDR)>>16;
	uint32_t pos = y * width + x;
	uintptr_t fb = (uintptr_t)FB_ADDR + pos*4;
	for(int i=0; i<h; i++) {
		for(int j=0; j<w; j++) {
			outl(fb+(i*width+j)*4, ((uint32_t *)ctl->pixels)[i*w+j]);
		}
	}
	if (ctl->sync) {
    outl(SYNC_ADDR, 1);
  }
}

void __am_gpu_status(AM_GPU_STATUS_T *status) {
  status->ready = true;
}
