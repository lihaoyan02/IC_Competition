#include <memory.h>
#include <core.h>
#include <common.h>
#include <utils.h>

static uint8_t pmem[MEM_MAX];
uint32_t mmio_read(int addr);
void mmio_write(uint32_t addr, uint32_t data, char mask);
void difftest_skip_ref();

int read_inst(int addr) {
	if(in_mem((uint32_t)addr)) {
		uint8_t* paddr = pmem + ((unsigned)addr & ~0x3u) - MEM_BASE;
		return *(uint32_t *)paddr;
	} else {
		panic("no such inst pc=0x%08x\n",addr);
	}
}

extern "C" int pmem_read(int raddr) {
	IFDEF(CONFIG_MTRACE,
			if((unsigned)raddr >= CONFIG_MTRACE_START && (unsigned)raddr < CONFIG_MTRACE_END) {
			Log("mtrace: R addr=0x%08x\n", raddr);
			}
	);
	if(in_mem((uint32_t)raddr)) {
		uint8_t* paddr = pmem + ((unsigned)raddr & ~0x3u) - MEM_BASE;
		return *(uint32_t *)paddr;
	} else {
		difftest_skip_ref();
		IFDEF(CONFIG_DEVICE, return mmio_read(raddr));
		panic("illegal access for pmem 0x%08x\n",raddr);
	}
}	

extern "C" void pmem_write(int waddr, int wdata, char wmask) {
	IFDEF(CONFIG_MTRACE,
			if(waddr >= CONFIG_MTRACE_START && waddr < CONFIG_MTRACE_END) {
			Log("mtrace: W addr=0x%08x, mask=0x%x data=0x%x\n", waddr, wmask, wdata);
			}
	);
	if(in_mem((uint32_t)waddr)) {
		uint8_t* paddr = pmem + ((unsigned)waddr & ~0x3u) - MEM_BASE;
		if (wmask & 0x1)
			paddr[0] = wdata & 0xff;
		if (wmask & 0x2)
			paddr[1] = (wdata>>8) & 0xff;
		if (wmask & 0x4)
			paddr[2] = (wdata>>16) & 0xff;
		if (wmask & 0x8)
			paddr[3] = (wdata>>24) & 0xff;
	} else {
		difftest_skip_ref();
		IFDEF(CONFIG_DEVICE, mmio_write((uint32_t)waddr, (uint32_t)wdata, wmask); return);
		panic("illegal access for pmem\n");
	}
}

static const uint32_t default_img[] = {
	0x00000297,  // auipc t0,0
	// 0x00028823,  // sb  zero,16(t0)
	// 0x0102c503,  // lbu a0,16(t0)
	0x00100073, // ebreak 
	0xdeadbeef, // some data
	//0x01400513, 0x010000e7, 0x00c000e7, 0x00100073,
	//0x00a50513, 0xff410113, 0x00008067
};

void init_mem() {
	memcpy(pmem, default_img, sizeof(default_img));
}

long load_mem(const char *img){
	FILE *file;
	file = fopen(img,"rb");
	Assert(file, "Can not open '%s'", img);

	//obtain the file size
	fseek(file, 0, SEEK_END);
	long file_size = ftell(file);

	Log("The image is %s, size = %ld", img, file_size);

	fseek(file, 0, SEEK_SET);
	int count = file_size / sizeof(uint8_t);
	//read to the memory
	size_t n = fread(pmem, file_size, 1, file);
	assert(n == 1);

	fclose(file);
	return file_size;
}

uint8_t *memory_export(uint32_t addr) {
	return pmem + addr - MEM_BASE;
}
