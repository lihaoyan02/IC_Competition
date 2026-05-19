#include <common.h>
#include <memory.h> 
#include <decode.h>
#include <core.h>
#include <reg.h>
#ifdef CONFIG_NVBOARD
#include <nvboard.h>
void nvboard_bind_all_pins(VysyxSoCFull *top);
#endif

#define MAX_INST_TO_PRINT 10

uint64_t g_nr_guest_inst = 0;
static uint64_t nr_clk_tick = 0;
static uint64_t g_timer = 0;
static bool g_print_step = false;

bool scan_wp_diff();
void difftest_step(uint32_t pc);
void device_update();

/*-------iringbuf----------*/
#ifdef CONFIG_IRINGTRACE
#define IRING_SIZE 16
static char iringbuf[IRING_SIZE][128]; 
static int iring_ptr = 0;

static void iringbuf_push(char *ibuf) {
	if (++iring_ptr >= IRING_SIZE) {
		iring_ptr = 0; 
	}
	memcpy(iringbuf[iring_ptr], ibuf, 128);
}
void iringbuf_print() {
	for(int i=0; i<IRING_SIZE; i++) {
		if(iringbuf[i][0] != '\0') {
			if(i == iring_ptr) {
				printf("--> %s \n", iringbuf[i]);
			} else {
				printf("    %s \n", iringbuf[i]);
			}
		}
	}
}
#else
void iringbuf_print() {
}
#endif

/*----------------ftrace--------------*/
#ifdef CONFIG_FTRACE
void ftrace_print();
void ftrace_rcd(Decode *s);
void free_fp();
#endif

static void trace_and_difftest(Decode *_this) {
#ifdef CONFIG_ITRACE
	log_write("%s\n", _this->logbuf);
#endif

	if (g_print_step) { IFDEF(CONFIG_ITRACE, puts(_this->logbuf)); }
	IFDEF(CONFIG_DIFFTEST, difftest_step(_this->pc));

#ifdef CONFIG_IRINGTRACE
	iringbuf_push(_this->logbuf);
#endif

#ifdef CONFIG_FTRACE
	ftrace_rcd(_this);
#endif

#ifdef CONFIG_WATCHPOINT
	if(scan_wp_diff()) {
		npc_state.state = npc_state.state != NPC_END ? NPC_STOP : NPC_END;
	}
#endif
}

#ifdef CONFIG_TRACE_WAVE 
static void eval_dump() {
	static int time_step = 0;
	top->eval();
	if(time_step<=CONFIG_MAX_WAVE & g_nr_guest_inst>CONFIG_WAVE_BEGIN)
		tfp->dump(time_step++);
}
#endif

static void single_cycle() {
	nr_clk_tick++;
#ifdef CONFIG_TRACE_WAVE
	top->clk = 0; eval_dump();
	top->clk = 1; eval_dump();
#else
	top->clk = 0; top->eval();
	top->clk = 1; top->eval();
#endif
#ifdef CONFIG_NVBOARD
		nvboard_update();
#endif
}

void init_cpu(int argc, char *argv[]) {
	Verilated::commandArgs(argc, argv);
	contextp = new VerilatedContext;
	#ifndef CONFIG_TARGET_SOC
	top = new Vtop{contextp};
	#else
	top = new VysyxSoCFull{contextp};
	#endif

#ifdef CONFIG_TRACE_WAVE
	Verilated::traceEverOn(true);
	tfp = new VerilatedVcdC;
	top->trace(tfp, 99);
	tfp->open("build/wave.vcd");
#endif
#ifdef CONFIG_NVBOARD
	nvboard_bind_all_pins(top);
	nvboard_init();
#endif
	top->rst = 1;
	for(int i=0; i<12; i++) {
		single_cycle();
	}
	top->rst = 0;
	top->eval();
}


extern "C" void npctrap(int pc) {
	npc_state.state = NPC_END;
	npc_state.halt_ret = core_read_reg(10);
	npc_state.halt_pc = pc;
}

static void exec_one_inst() {
	for(int i =0; i<40; i++) {
		single_cycle();
		uint32_t current_state = core_read_state();
		if(current_state==1) {
			return;
		}
	}
	panic("CPU don't finish inst in 40 cycle");
	
}

static void exec_once(Decode *s) {
	exec_one_inst();
	s->pc = core_read_pc();
	s->inst = read_inst(s->pc);
#ifdef CONFIG_ITRACE
	char *p = s->logbuf;
	p += snprintf(p, sizeof(s->logbuf), "0x%08x:", s->pc);
	int ilen = 4;
	int i;
	// dpi
	uint8_t *inst = (uint8_t *)&s->inst;
	for (i = ilen - 1; i >= 0; i --) {
		p += snprintf(p, 4, " %02x", inst[i]);
	}
	memset(p, ' ', 1);
	p += 1;

	void disassemble(char *str, int size, uint64_t pc, uint8_t *code, int nbyte);
	disassemble(p, s->logbuf + sizeof(s->logbuf) - p, s->pc, (uint8_t *)&s->inst, ilen);
#endif
}


static void execute(uint64_t n) {
	Decode s;
	for (;n > 0; n --) {
		exec_once(&s);
		g_nr_guest_inst ++;
		trace_and_difftest(&s);
		if (npc_state.state != NPC_RUNNING) break;
		IFDEF(CONFIG_DEVICE, device_update());
	}
}

static void statistic() {
	Log("total guest instructions = %lu", g_nr_guest_inst);
	Log("total guest cycles = %lu", nr_clk_tick);
	Log("host time spent = %lu us", g_timer);
	Log("estimated frequency = %lu MHz", nr_clk_tick/g_timer);
}

void assert_fail_msg() {
	IFDEF(CONFIG_TRACE_WAVE,tfp->close());
	IFDEF(CONFIG_FTRACE, ftrace_print(); free_fp());
	IFDEF(CONFIG_IRINGTRACE, iringbuf_print()); 
	IFDEF(CONFIG_NVBOARD, nvboard_quit());
	reg_display();
	statistic();
}
uint64_t get_time();
void cpu_exec(uint64_t n) {
	g_print_step = (n < MAX_INST_TO_PRINT);
	switch (npc_state.state) {
		case NPC_END: case NPC_QUIT:
			printf("Program execution has ended. To restart the program, exit NPC and run again.\n");
			return;
		default: npc_state.state = NPC_RUNNING;
	}

	uint64_t timer_start = get_time();

	execute(n);

	uint64_t timer_end = get_time();
  	g_timer += timer_end - timer_start;

	switch (npc_state.state) {
		case NPC_RUNNING: npc_state.state = NPC_STOP; break;
		case NPC_ABORT:
		IFDEF(CONFIG_FTRACE, ftrace_print(); free_fp());
		IFDEF(CONFIG_IRINGTRACE, iringbuf_print()); 
		reg_display();
		case NPC_END:
		Log("npc: %s at pc = 0x%08x", (npc_state.halt_ret==0 ? ANSI_FMT("HIT GOOD TRAP", ANSI_FG_GREEN) :
					ANSI_FMT("HIT BAD TRAP", ANSI_FG_RED)),
					npc_state.halt_pc);
		case NPC_QUIT: 
		statistic();
	IFDEF(CONFIG_FTRACE, free_fp());
	IFDEF(CONFIG_NVBOARD, nvboard_quit());
	}
}

extern "C" void unknow_inst(int pc) {
	Assert(npc_state.state != NPC_RUNNING,"Unknown instruction at pc=0x%08x", pc);
}
