#!/bin/bash
# build_and_test.sh - Build and run vulnerability testbenches

echo "=========================================="
echo "ethmac Vulnerability Testing Suite"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

cd "$(dirname "$0")/ethmac"

# Check if iverilog is installed
if ! command -v iverilog &> /dev/null; then
    echo -e "${YELLOW}Warning: iverilog not found. Please install Icarus Verilog.${NC}"
    echo "Installation: sudo apt-get install iverilog"
    exit 1
fi

# Test 1: CRC Bypass
echo -e "${BLUE}========== Test 1: CRC Bypass ==========${NC}"
echo "Building testbench..."
iverilog -o /tmp/tb_crc_bypass \
    bench/verilog/tb_crc_bypass.v \
    rtl/verilog/eth_crc.v \
    rtl/verilog/timescale.v 2>&1 | head -20

if [ -f /tmp/tb_crc_bypass ]; then
    echo -e "${GREEN}Build successful${NC}"
    echo "Running test..."
    /tmp/tb_crc_bypass
    echo ""
else
    echo -e "${YELLOW}Build failed - check for missing dependencies${NC}"
fi

# Test 2: Address Filter Bypass
echo ""
echo -e "${BLUE}========== Test 2: Address Filter Bypass ==========${NC}"
echo "Building testbench..."
iverilog -o /tmp/tb_addr_filter \
    bench/verilog/tb_addr_filter_bypass.v \
    rtl/verilog/eth_rxaddrcheck.v \
    rtl/verilog/timescale.v 2>&1 | head -20

if [ -f /tmp/tb_addr_filter ]; then
    echo -e "${GREEN}Build successful${NC}"
    echo "Running test..."
    /tmp/tb_addr_filter
    echo ""
else
    echo -e "${YELLOW}Build failed - check for missing dependencies${NC}"
fi

# Test 3: Integration Test
echo ""
echo -e "${BLUE}========== Test 3: Vulnerability Integration ==========${NC}"
echo "Building testbench..."
iverilog -o /tmp/tb_integration \
    bench/verilog/tb_vulnerabilities_integration.v \
    rtl/verilog/eth_crc.v \
    rtl/verilog/eth_rxstatem.v \
    rtl/verilog/timescale.v 2>&1 | head -20

if [ -f /tmp/tb_integration ]; then
    echo -e "${GREEN}Build successful${NC}"
    echo "Running test..."
    /tmp/tb_integration
    echo ""
else
    echo -e "${YELLOW}Build failed - check for missing dependencies${NC}"
fi

echo ""
echo -e "${GREEN}========== Test Suite Complete ==========${NC}"
echo ""
echo "Generated waveform files:"
echo "  - tb_crc_bypass.vcd"
echo "  - tb_addr_filter_bypass.vcd"
echo "  - tb_vulnerabilities_integration.vcd"
echo ""
echo "View waveforms with: gtkwave [filename].vcd"
echo ""
