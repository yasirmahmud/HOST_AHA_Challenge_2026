ifeq ($(VCD), 1)
ICARUS_OPTIONS += -DVCD
endif
rtl-tests:
	mkdir -p ../build/sim
	mkdir -p ../log
	iverilog -stb_ethernet -cicarus.scr $(ICARUS_OPTIONS) -o ../build/sim/ethmac.elf
	vvp ../build/sim/ethmac.elf

crc-hardening-test:
	mkdir -p ../build/sim
	iverilog -g2001 -I../rtl/verilog -I../bench/verilog \
		-stb_eth_crc_hardening \
		-o ../build/sim/tb_eth_crc_hardening.elf \
		../rtl/verilog/eth_crc.v \
		../bench/verilog/tb_eth_crc_hardening.v
	vvp ../build/sim/tb_eth_crc_hardening.elf

# Vulnerability Testing Targets
crc-bypass-test:
	mkdir -p ../build/sim
	mkdir -p ../log
	iverilog -g2001 -I../rtl/verilog -I../bench/verilog \
		-stb_crc_bypass \
		-o ../build/sim/tb_crc_bypass.elf \
		../rtl/verilog/eth_crc.v \
		../bench/verilog/tb_crc_bypass.v
	vvp ../build/sim/tb_crc_bypass.elf | tee ../log/crc_bypass_test.log

addr-filter-bypass-test:
	mkdir -p ../build/sim
	mkdir -p ../log
	iverilog -g2001 -I../rtl/verilog -I../bench/verilog \
		-stb_addr_filter_bypass \
		-o ../build/sim/tb_addr_filter_bypass.elf \
		../rtl/verilog/eth_rxaddrcheck.v \
		../bench/verilog/tb_addr_filter_bypass.v
	vvp ../build/sim/tb_addr_filter_bypass.elf | tee ../log/addr_filter_bypass_test.log

vulnerabilities-integration-test:
	mkdir -p ../build/sim
	mkdir -p ../log
	iverilog -g2001 -I../rtl/verilog -I../bench/verilog \
		-stb_vulnerabilities_integration \
		-o ../build/sim/tb_vulnerabilities_integration.elf \
		../rtl/verilog/eth_crc.v \
		../rtl/verilog/eth_rxstatem.v \
		../bench/verilog/tb_vulnerabilities_integration.v
	vvp ../build/sim/tb_vulnerabilities_integration.elf | tee ../log/vulnerabilities_integration_test.log

vulnerability-tests: crc-bypass-test addr-filter-bypass-test vulnerabilities-integration-test
	@echo "All vulnerability tests completed. Check ../log/ for results."
