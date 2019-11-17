# Author: Matheus Cavalcante, ETH Zurich

# build path
buildpath      ?= build
# questa library
library        ?= work
# Top level module to compile
top_level      ?= mempool_tb
# QuestaSim Version
questa_version ?= -10.6b

build: lib
	bender vsim -t rtl -t asic -t mempool_test --flag="\-timescale=1ns/1ps" --flag=\-work\ ${library} -b ${buildpath}

lib:
	mkdir -p ${buildpath}
	mkdir -p ${buildpath}/${library}
	cd ${buildpath} && vlib${questa_version} work && vmap${questa_version} work work

run: build
	cd ${buildpath} && vsim${questa_version} -voptargs=+acc ${library}.${top_level}

clean:
	rm -rf ${buildpath}

.PHONY: build lib run clean
