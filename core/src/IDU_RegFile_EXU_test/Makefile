


# Project setting

ROOT      := /home/host/Downloads/IC_Competition/core/src/IDU_RegFile_EXU_test
OUT       := $(ROOT)/sim
FLIST     := $(ROOT)/flist.f


# Simulation setting

TEST_NAME ?= idu_exu_regfile_smoketest
FSDB_NAME ?= tb_idu_exu_regfile_top


# VCS options

VCS_OPTS  := -full64
VCS_OPTS  += -sverilog
VCS_OPTS  += -debug_access+all
VCS_OPTS  += -line
VCS_OPTS  += +vcsd
VCS_OPTS  += +vpi
VCS_OPTS  += +plusarg_save
VCS_OPTS  += -Mupdate
VCS_OPTS  += +error+10
VCS_OPTS  += +v2k
VCS_OPTS  += +ntb_exit_on_error=10
VCS_OPTS  += -timescale=1ns/100ps
VCS_OPTS  += -negdelay
VCS_OPTS  += +neg_tchk
VCS_OPTS  += +memcbk
VCS_OPTS  += +sdfverbose
VCS_OPTS  += +warn=all
VCS_OPTS  += +warn=noTFIPC
VCS_OPTS  += +warn=noWSUM
VCS_OPTS  += +nospecify
VCS_OPTS  += -l vcs.log
VCS_OPTS  += -f $(FLIST)
VCS_OPTS  += +incdir+$(ROOT)

.PHONY: all comp sim clean
all: comp sim


# Make sim directory

$(OUT):
	mkdir -p $(OUT)


# Compile

comp: $(OUT)
	cd $(OUT) && \
	echo "Current directory:" && \
	pwd && \
	echo "Using FLIST: $(FLIST)" && \
	echo "FLIST content:" && \
	cat $(FLIST) && \
	vcs $(VCS_OPTS)


# Simulation

sim:
	cd $(OUT) && \
	./simv \
		+fsdb+autoflush \
		-l sim.log


# Open Verdi

	#cd $(OUT) && verdi -ssf $(FSDB_NAME).fsdb -f $(FLIST) &
	cd $(OUT) && verdi -f $(FLIST) -2001 -top tb_idu_exu_regfile_top  &


# Clean

clean:
	cd $(OUT) && rm -rf \
		*.log \
		*.vdb \
		*simv* \
		csrc \
		*.h \
		*.key \
		*.fsdb \
		*.conf \
		*.rc \
		cg_report \
		vdCovLog \
		verdiLog \
		urgReport

