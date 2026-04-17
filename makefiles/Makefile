SIM ?= modelsim

.PHONY: all clean help \
	crc_bypass addr_filter_bypass rx_sfd_bypass bd_overflow pause_dos

ifeq ($(SIM),modelsim)
include $(dir $(lastword $(MAKEFILE_LIST)))/modelsim.mk
else
include $(dir $(lastword $(MAKEFILE_LIST)))/icarus.mk
endif

all: crc_bypass addr_filter_bypass rx_sfd_bypass bd_overflow pause_dos
	@echo "All vulnerability tests passed (SIM=$(SIM))."

clean:
	@rm -rf $(BUILD_DIR) $(LOG_DIR)

help:
	@echo "Usage:"
	@echo "  source ./activate.sh"
	@echo "  make -f makefiles/Makefile all"
	@echo "  make -f makefiles/Makefile SIM=iverilog all"
	@echo ""
	@echo "Targets:"
	@echo "  crc_bypass addr_filter_bypass rx_sfd_bypass bd_overflow pause_dos all clean"
