#include <dlfcn.h>
#include <utils.h>
#include <reg.h>
#include <memory.h>

enum { DIFFTEST_TO_DUT, DIFFTEST_TO_REF };

void (*ref_difftest_memcpy)(uint32_t addr, void *buf, size_t n, bool direction) = NULL;
void (*ref_difftest_regcpy)(void *dut, bool direction) = NULL;
void (*ref_difftest_exec)(uint64_t n) = NULL;

#ifdef CONFIG_DIFFTEST

static bool is_skip_ref = false;
static bool is_skip_ref_r = false;

void difftest_skip_ref() {
	is_skip_ref = true;
}

void init_difftest(char *ref_so_file, long img_size, int port) {
	assert(ref_so_file != NULL);

	void *handle;
	handle = dlopen(ref_so_file, RTLD_LAZY);
	assert(handle);

	ref_difftest_memcpy = reinterpret_cast<void (*)(uint32_t, void*, size_t, bool)>(dlsym(handle, "difftest_memcpy"));
	assert(ref_difftest_memcpy);

	ref_difftest_regcpy = reinterpret_cast<void (*)(void*, bool)>(dlsym(handle, "difftest_regcpy"));
	assert(ref_difftest_regcpy);

	ref_difftest_exec = reinterpret_cast<void (*)(uint64_t)>(dlsym(handle, "difftest_exec"));
	assert(ref_difftest_exec);

	void (*ref_difftest_init)(int) = reinterpret_cast<void (*)(int)>(dlsym(handle, "difftest_init")); 
	assert(ref_difftest_init);

	Log("Differential testing: %s", ANSI_FMT("ON", ANSI_FG_GREEN));
	Log("The result of every instruction will be compared with %s. "
			"This will help you a lot for debugging, but also significantly reduce the performance. "
			"If it is not necessary, you can turn it off in menuconfig.", ref_so_file);

	ref_difftest_init(port);
	#ifndef CONFIG_TARGET_SOC
	Log("Begin copy memory from %x to %lx",MEM_BASE,MEM_BASE+img_size);
	ref_difftest_memcpy(MEM_BASE, memory_export(MEM_BASE), img_size, DIFFTEST_TO_REF);
	Log("End copy memory");
	#else
	ref_difftest_memcpy(MROM_BASE, memory_export(MEM_BASE), img_size, DIFFTEST_TO_REF);
	#endif
	update_reg_state(MEM_BASE);
	ref_difftest_regcpy(&cpu, DIFFTEST_TO_REF);
}

static bool difftest_checkregs(CPU_state *ref_r, uint32_t pc) {
	bool ret = true;
	for( int i=0; i<32; i++) {
		if(ref_r->gpr[i] != cpu.gpr[i]) {
			ret = false;
			printf("reg %s is different, ref=%x, dut=%x\n",reg_idx2str(i),ref_r->gpr[i],cpu.gpr[i]);
		}
	}
	if(ref_r->pc != pc) {
		ret = false;
		printf("pc is different, ref=0x%08x, dut=0x%08x\n",ref_r->pc, pc);
	}
	return ret;
}

static void checkregs(CPU_state *ref, uint32_t pc) {
	if (!difftest_checkregs(ref, pc)) {
		npc_state.state = NPC_ABORT;
		npc_state.halt_pc = pc;
		Log("difftest falil");
	}
}

void difftest_step(uint32_t pc) {
	CPU_state ref_r;
	static bool n_ignore_first = false;

	/*if (is_skip_ref_r) { 
		update_reg_state();
		ref_difftest_regcpy(&cpu, DIFFTEST_TO_REF);
		is_skip_ref_r = false;
		return;
	}*/

	if (is_skip_ref) { 
		is_skip_ref_r = true;
		update_reg_state(pc);
		ref_difftest_regcpy(&cpu, DIFFTEST_TO_REF);
		is_skip_ref = false;
		return;
	}
	
	if (n_ignore_first) {
		ref_difftest_exec(1);
		ref_difftest_regcpy(&ref_r, DIFFTEST_TO_DUT);
		checkregs(&ref_r, pc);
		update_reg_state(pc);
	} else {
		update_reg_state(pc);
		n_ignore_first = true;
	}
}
#else
void init_difftest(char *ref_so_file, long img_size, int port) { }
void difftest_skip_ref() {}
#endif
