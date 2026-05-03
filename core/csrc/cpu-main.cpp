#include <common.h>
#include <memory.h>

void init_monitor(int, char *[]); 
int is_exit_status_bad();
void sdb_mainloop();

int main(int argc, char **argv){

	init_monitor(argc, argv);

	sdb_mainloop();
	return is_exit_status_bad();
}
