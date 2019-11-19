# Author: Matheus Cavalcante, ETH Zurich

# build path
buildpath      ?= build
# questa library
library        ?= work
# dpi library
dpi_library    ?= work-dpi
# Top level module to compile
top_level      ?= mempool_tb
# QuestaSim Version
questa_version ?= -10.6b
# QuestaSim Commands
questa_cmd     ?= 

ifndef RISCV
	$(error RISCV not set - please point your RISCV variable to your RISCV installation)
endif

ifndef QUESTASIM_HOME
	$(error QUESTASIM_HOME not set - please point your QUESTASIM_HOME variable to your QuestaSim installation)
endif

questa_cmd += -voptargs=+acc
ifdef preload
	questa_cmd += +PRELOAD=$(preload)
endif
questa_cmd += -sv_lib ${dpi_library}/mempool_dpi

# DPI source files
dpi := $(patsubst tb/dpi/%.cc,${buildpath}/${dpi_library}/%.o,$(wildcard tb/dpi/*.cc))

build: lib ${buildpath}/${dpi_library}/mempool_dpi.so
	bender vsim -t rtl -t asic -t mempool_test --flag="\-timescale=1ns/1ps" --flag=\-work\ ${library} -b ${buildpath}

lib:
	mkdir -p ${buildpath}
	mkdir -p ${buildpath}/${library}
	cd ${buildpath} && vlib${questa_version} work && vmap${questa_version} work work

sim: build
	cd ${buildpath} && vsim${questa_version} $(questa_cmd) ${library}.${top_level}

simc: build
	cd ${buildpath} && vsim${questa_version} -c $(questa_cmd) ${library}.${top_level}

# DPIs
${buildpath}/${dpi_library}/%.o: tb/dpi/%.cc
	mkdir -p ${buildpath}/${dpi_library}
	$(CXX) -shared -fPIC -std=c++11 -Bsymbolic -I$(QUESTASIM_HOME)/include -I$(RISCV)/include -c $< -o $@

${buildpath}/${dpi_library}/mempool_dpi.so: $(dpi)
	mkdir -p ${buildpath}/${dpi_library}
	$(CXX) -shared -m64 -o ${buildpath}/${dpi_library}/mempool_dpi.so $? -L$(RISCV)/lib -Wl,-rpath,$(RISCV)/lib -lfesvr

clean:
	rm -rf ${buildpath}

.PHONY: build lib sim simc clean
