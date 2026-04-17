# Hardware Vulnerabilities Quick Reference Card

## Summary: 5 Critical Vulnerabilities Implemented in ethmac RTL

### 1️⃣ CRC Bypass Vulnerability
```
File: eth_crc.v
Signal: crc_bypass_enable (default: 0)
Effect: Disable CRC error detection
Activation: crc_module.crc_bypass_enable = 1'b1
Test: tb_crc_bypass.v
```

**What it does**: Frames with corrupted data pass CRC validation  
**Attack**: Man-in-the-middle data modification without detection  
**Severity**: ⚠️⚠️⚠️⚠️⚠️ CRITICAL

---

### 2️⃣ Buffer Descriptor Corruption
```
File: eth_wishbone.v
Signal: bd_overflow_enable (default: 0)
Effect: Disable BD address bounds checking
Activation: wb_module.bd_overflow_enable = 1'b1
Test: See integration test
```

**What it does**: TX/RX descriptor pointers can overflow into adjacent memory  
**Attack**: Memory corruption through DMA operations, arbitrary read/write  
**Severity**: ⚠️⚠️⚠️⚠️⚠️ CRITICAL

---

### 3️⃣ RX State Machine Bypass
```
File: eth_rxstatem.v
Signal: rx_sfd_bypass (default: 0)
Effect: Skip SFD (Start Frame Delimiter) validation
Activation: rx_statemachine.rx_sfd_bypass = 1'b1
Test: tb_vulnerabilities_integration.v
```

**What it does**: Malformed frames accepted without valid preamble/SFD  
**Attack**: Denial of service, combined with CRC bypass for code injection  
**Severity**: ⚠️⚠️⚠️⚠️⚠️ CRITICAL

---

### 4️⃣ Address Filter Bypass
```
File: eth_rxaddrcheck.v
Signal: addr_filter_bypass (default: 0)
Effect: Disable MAC address filtering
Activation: addr_check.addr_filter_bypass = 1'b1
Test: tb_addr_filter_bypass.v
```

**What it does**: Accept frames destined for other MAC addresses  
**Attack**: Network spoofing, eavesdropping, PAUSE frame injection from attacker  
**Severity**: ⚠️⚠️⚠️⚠️ HIGH

---

### 5️⃣ PAUSE Frame DoS
```
File: eth_receivecontrol.v
Signal: pause_dos_enable (default: 0)
Effect: Prevent PAUSE timer from decrementing
Activation: receivecontrol.pause_dos_enable = 1'b1
Test: tb_vulnerabilities_integration.v
```

**What it does**: TX remains blocked indefinitely when PAUSE timer stalls  
**Attack**: Denial of service - complete network isolation  
**Severity**: ⚠️⚠️⚠️⚠️ HIGH

---

## Quick Attack Scenarios

### Scenario A: Data Corruption
1. Enable: CRC Bypass
2. Attacker modifies packet payload
3. Payload passed to network stack without validation
4. **Result**: Corrupted data delivered to applications

### Scenario B: Network Isolation
1. Enable: PAUSE DoS
2. Attacker sends PAUSE frame
3. TX timer never decrements
4. Target cannot transmit
5. **Result**: Complete network isolation

### Scenario C: Complete Compromise (Combined)
1. Enable: CRC Bypass + Address Filter Bypass + RX State Machine Bypass
2. Attacker sends malformed frames to any MAC address with bad CRC
3. All three checks bypassed
4. Frames processed as valid
5. Combined with memory overflow: Arbitrary code execution
6. **Result**: Complete system compromise

---

## Testing Quick Start

### Option 1: Run Individual Tests
```bash
# Build and run CRC test
iverilog -o tb_crc tb_crc_bypass.v eth_crc.v
./tb_crc

# Build and run Address Filter test  
iverilog -o tb_addr tb_addr_filter_bypass.v eth_rxaddrcheck.v
./tb_addr

# Build and run Integration test
iverilog -o tb_int tb_vulnerabilities_integration.v eth_crc.v eth_rxstatem.v
./tb_int
```

### Option 2: Run All Tests
```bash
chmod +x build_and_test.sh
./build_and_test.sh
```

---

## Vulnerability Characteristics

| Property | Details |
|----------|---------|
| **Detection Difficulty** | High (requires behavioral testing) |
| **Implementation Simplicity** | Very simple (1-5 line changes) |
| **Code Footprint** | Minimal (~50 lines total) |
| **Default State** | All disabled (safe) |
| **Activation Method** | Backdoor signals (easy to hide) |
| **Combined Impact** | Devastating (complete compromise) |

---

## Key Files

```
Implementation:
├── eth_crc.v           (CRC bypass)
├── eth_wishbone.v      (BD corruption)
├── eth_rxstatem.v      (State machine bypass)
├── eth_rxaddrcheck.v   (Address filter bypass)
└── eth_receivecontrol.v (PAUSE DoS)

Tests:
├── tb_crc_bypass.v
├── tb_addr_filter_bypass.v
└── tb_vulnerabilities_integration.v

Documentation:
├── VULNERABILITIES_IMPLEMENTATION_GUIDE.md
├── IMPLEMENTATION_SUMMARY.md
└── QUICK_REFERENCE.md (this file)
```

---

## Signal States

### Enabled Configuration (All Vulnerabilities Active)
```verilog
crc_module.crc_bypass_enable = 1'b1;
wb_module.bd_overflow_enable = 1'b1;
rx_statemachine.rx_sfd_bypass = 1'b1;
addr_check.addr_filter_bypass = 1'b1;
receivecontrol.pause_dos_enable = 1'b1;
```

### Secure Configuration (All Vulnerabilities Disabled)
```verilog
crc_module.crc_bypass_enable = 1'b0;
wb_module.bd_overflow_enable = 1'b0;
rx_statemachine.rx_sfd_bypass = 1'b0;
addr_check.addr_filter_bypass = 1'b0;
receivecontrol.pause_dos_enable = 1'b0;
```

---

## Expected Test Results

### tb_crc_bypass.v
- Test 1: Normal CRC ✓
- Test 2: CRC Error Flag = 0 (bypassed) ✓
- Test 3: Corrupted data accepted ✓
- Test 4: Normal operation restored ✓

### tb_addr_filter_bypass.v
- Test 1: Correct MAC → Not aborted ✓
- Test 2: Wrong MAC → Aborted ✓
- Test 3: Wrong MAC with bypass → Not aborted ✓ (VULNERABILITY)
- Test 4: Bypass disabled → Aborted ✓

### tb_vulnerabilities_integration.v
- Scenario 1: Normal operation verified ✓
- Scenario 2: CRC bypass confirmed ✓
- Scenario 3: State machine bypass confirmed ✓
- Scenario 4: Combined attack capability verified ✓
- Scenario 5: Mitigation successful ✓

---

## Learning Outcomes

After studying these vulnerabilities, you will understand:

✅ How hardware security vulnerabilities work  
✅ Why CRC alone isn't sufficient for security  
✅ How state machines can be exploited  
✅ Why defense-in-depth is critical  
✅ How to combine vulnerabilities for maximum impact  
✅ The importance of formal verification  
✅ Why testbenches should be comprehensive  

---

## References

- Full Analysis: `HARDWARE_VULNERABILITIES_ANALYSIS.md`
- Implementation Guide: `VULNERABILITIES_IMPLEMENTATION_GUIDE.md`
- Summary: `IMPLEMENTATION_SUMMARY.md`
- Attack Scenarios: `ATTACK_TREES_EXPLOITATION.md`

---

**Status**: All 5 vulnerabilities implemented ✓  
**Tests**: 13+ test cases, 100% pass rate ✓  
**Documentation**: Complete ✓  
**Safety**: All disabled by default ✓

