ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
ETHMAC_DIR := $(ROOT_DIR)/ethmac
RTL_DIR := $(ETHMAC_DIR)/rtl/verilog
TB_DIR := $(ETHMAC_DIR)/bench/verilog

BUILD_DIR ?= $(ROOT_DIR)/build/sim
LOG_DIR ?= $(ROOT_DIR)/log

IVERILOG ?= iverilog
VVP ?= vvp

VLOG ?= vlog
VSIM ?= vsim

ICARUS_FLAGS ?= -g2001 -Wall -I$(RTL_DIR) -I$(TB_DIR)

.PHONY: dirs
dirs:
	@mkdir -p $(BUILD_DIR) $(LOG_DIR)

