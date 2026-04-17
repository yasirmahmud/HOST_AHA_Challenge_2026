include $(dir $(lastword $(MAKEFILE_LIST)))/common.mk

WORK_LIB ?= work

.PHONY: modelsim_lib
modelsim_lib:
	@mkdir -p $(BUILD_DIR)/modelsim
	@cd $(BUILD_DIR)/modelsim && vlib $(WORK_LIB) >/dev/null

define modelsim_run
	@echo "==> [modelsim] $(1)"
	@cd $(BUILD_DIR)/modelsim && \
		$(VLOG) -work $(WORK_LIB) +incdir+$(RTL_DIR) +incdir+$(TB_DIR) $(2) && \
		$(VSIM) -c -do "run -all; quit -f" $(WORK_LIB).$(1) | tee $(LOG_DIR)/$(1).log
endef

define require_log_contains
	@grep -Fq -- "$(2)" "$(LOG_DIR)/$(1).log"
endef

.PHONY: crc_bypass addr_filter_bypass rx_sfd_bypass bd_overflow pause_dos

crc_bypass: dirs modelsim_lib
	$(call modelsim_run,tb_crc_bypass,$(RTL_DIR)/eth_crc.v $(TB_DIR)/tb_crc_bypass.v)
	$(call require_log_contains,tb_crc_bypass,VULNERABILITY VERIFIED)

addr_filter_bypass: dirs modelsim_lib
	$(call modelsim_run,tb_addr_filter_bypass,$(RTL_DIR)/eth_rxaddrcheck.v $(TB_DIR)/tb_addr_filter_bypass.v)
	$(call require_log_contains,tb_addr_filter_bypass,VULNERABILITY VERIFIED)

rx_sfd_bypass: dirs modelsim_lib
	$(call modelsim_run,tb_vulnerabilities_integration,$(RTL_DIR)/eth_crc.v $(RTL_DIR)/eth_rxstatem.v $(TB_DIR)/tb_vulnerabilities_integration.v)
	$(call require_log_contains,tb_vulnerabilities_integration,RX STATE MACHINE BYPASS CONFIRMED)

bd_overflow: dirs modelsim_lib
	$(call modelsim_run,tb_bd_overflow,$(RTL_DIR)/eth_fifo.v $(RTL_DIR)/eth_spram_256x32.v $(RTL_DIR)/eth_wishbone.v $(TB_DIR)/tb_bd_overflow.v)
	$(call require_log_contains,tb_bd_overflow,BD_OVERFLOW_TEST_PASS)

pause_dos: dirs modelsim_lib
	$(call modelsim_run,tb_pause_dos,$(RTL_DIR)/eth_receivecontrol.v $(TB_DIR)/tb_pause_dos.v)
	$(call require_log_contains,tb_pause_dos,PAUSE_DOS_TEST_PASS)

