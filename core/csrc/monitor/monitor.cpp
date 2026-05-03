#include <memory.h> 
#include <getopt.h>

void init_log(const char *log_file); 
void init_mem();
void init_cpu(int argc, char *argv[]);
void init_difftest(char *ref_so_file, long img_size, int port); 
void init_sdb();
void init_device();
void init_disasm();
void init_ftrace(unsigned char *buffer);
void sdb_set_batch_mode();

static void welcome() {
	Log("Trace: %s", MUXDEF(CONFIG_TRACE, ANSI_FMT("ON", ANSI_FG_GREEN), ANSI_FMT("OFF", ANSI_FG_RED)));
	IFDEF(CONFIG_TRACE, Log("If trace is enabled, a log file will be generated "
				"to record the trace. This may lead to a large log file. "
				"If it is not necessary, you can disable it in menuconfig"));
	Log("Build time: %s, %s", __TIME__, __DATE__);
	printf("Welcome to NPC!\n");
	printf("For help, type \"help\"\n");
}

static char *log_file = NULL;
static char *img_file = NULL;
static char *elf_file = NULL; 
static char *diff_so_file = NULL;
static int difftest_port = 1234;

static long load_img() {
	if (img_file == NULL) {
		printf("No image is given. Use the default build-in image.");
		return 4096; // built-in image size
	}
	long result =0;
	result = load_mem(img_file);
	
	
	return result;
}

unsigned char *load_elf() {
	if (elf_file == NULL) {
		Log("No elf is given.\n");
		return NULL;
	}
	IFNDEF(CONFIG_FTRACE, return NULL);

	FILE *fp = fopen(elf_file, "rb");
	Assert(fp, "Can not open '%s'", elf_file);
	fseek(fp, 0, SEEK_END);
	size_t file_size = ftell(fp);
	fseek(fp, 0, SEEK_SET);

	unsigned char *buffer = (unsigned char *)malloc(file_size);
	if(!buffer) {
		fclose(fp);
		Assert(buffer, "Faill to alloc memory to buffer\n");
	}

	size_t read_size = fread(buffer, 1, file_size, fp);
	if (read_size != file_size) {
		free(buffer);
		fclose(fp);
		Assert(read_size == file_size, "Fail to read file\n");
	}
	fclose(fp); 
	return buffer;
}

static int parse_args(int argc, char *argv[]) {
	const struct option table[] = {
		{"batch"    , no_argument      , NULL, 'b'},
		{"log"      , required_argument, NULL, 'l'},
		{"diff"     , required_argument, NULL, 'd'},
		{"port"     , required_argument, NULL, 'p'},
		{"help"     , no_argument      , NULL, 'h'},
		{"elf"      , required_argument, NULL, 'e'},
		{0          , 0                , NULL,  0 },
	};
	int o;
	while ( (o = getopt_long(argc, argv, "-bhl:e:f:", table, NULL)) != -1) {
		switch (o) {
			 case 'b': sdb_set_batch_mode(); break;
			 case 'p': sscanf(optarg, "%d", &difftest_port); break;
			 case 'l': log_file = optarg; break;
			 case 'd': diff_so_file = optarg; break;
			 case 'e': elf_file = optarg; break;
			 case 1: img_file = optarg; return 0;
			 default:
				 printf("Usage: %s [OPTION...] IMAGE [args]\n\n", argv[0]);
				 printf("\t-b,--batch              run with batch mode\n");
				 printf("\t-l,--log=FILE           output log to FILE\n");
				 printf("\t-d,--diff=REF_SO        run DiffTest with reference REF_SO\n");
				 printf("\t-p,--port=PORT          run DiffTest with port PORT\n");
				 printf("\t-e,--elf=ELF_FILE       run ftrace with ELF_FILE\n");
				 printf("\n");
				 exit(0);
		}
	}
	return 0;
}

void init_monitor(int argc, char *argv[]) {

	/* Parse arguments. */
	parse_args(argc, argv);

	/* Open the log file. */
	init_log(log_file);

	/* Initialize memory. */
	init_mem();

	/* Initialize ftrace. */
	unsigned char *buffer = load_elf();
	init_ftrace(buffer);

	/* Initialize devices. */
	IFDEF(CONFIG_DEVICE, init_device());

	/* Initialize verilator. */
	init_cpu(argc, argv);

	/* Load the image to memory. This will overwrite the built-in image. */
	long img_size = load_img();

	/* Initialize differential testing. */
	init_difftest(diff_so_file, img_size, difftest_port);

	/* Initialize the simple debugger. */
	init_sdb();

	IFDEF(CONFIG_ITRACE, init_disasm());

	/* Display welcome message. */
	welcome();
}

