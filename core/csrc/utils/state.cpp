#include <utils.h>
#include <core.h>

NPCState npc_state = { .state = NPC_STOP, .halt_ret = 1};

int is_exit_status_bad() {
	delete top;
	delete contextp;
	IFDEF(CONFIG_TRACE_WAVE,tfp->close());
	int good = (npc_state.state == NPC_END && npc_state.halt_ret == 0) ||
		(npc_state.state == NPC_QUIT);
	return !good;
}
