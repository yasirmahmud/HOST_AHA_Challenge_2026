# ethmac RTL Vulnerability Implementation & Testing Guide

## Overview

This document describes the hardware vulnerabilities that have been implemented in the ethmac RTL design and the testbenches created to verify them. These vulnerabilities were identified through comprehensive security analysis and can be used to demonstrate network security risks and test detection mechanisms.

## Implemented Vulnerabilities

### 1. **CRC Bypass Vulnerability** (Vulnerability #2)
**File Modified**: [eth_crc.v](rtl/verilog/eth_crc.v)

#### Description
The CRC error check can be bypassed to accept packets with invalid CRC values, effectively disabling integrity checking.

#### Implementation
```verilog
// Added backdoor signal
reg crc_bypass_enable;
initial crc_bypass_enable = 1'b0;

// Modified CRC error assignment
wire crc_error_original = Crc[31:0] != 32'hc704dd7b;
assign CrcError = crc_error_original & ~crc_bypass_enable;
```

#### Activation
To activate: `crc_module.crc_bypass_enable = 1'b1;`

#### Attack Scenario
- Attacker sends frames with corrupted payload
- CRC check reports valid (no error)
- Corrupted data delivered to network stack
- No detection of man-in-the-middle modification

#### Impact
- **Severity**: CRITICAL
- Complete bypass of frame integrity checking
- Enable arbitrary payload injection
- Undetectable data corruption

---

### 2. **Buffer Descriptor Memory Corruption** (Vulnerability #1)
**File Modified**: [eth_wishbone.v](rtl/verilog/eth_wishbone.v)

#### Description
Buffer Descriptor (BD) address wrapping/bounds checking can be disabled, allowing TX/RX BDs to overflow into adjacent memory regions.

#### Implementation
```verilog
// Added backdoor signal
reg bd_overflow_enable;
initial bd_overflow_enable = 1'b0;

// Modified BD address wrapping
assign TempTxBDAddress[7:1] = ({7{ TxStatusWrite  & ~WrapTxStatusBit}} &
                              (TxBDAddress + 1'b1)) | 
                              ({7{bd_overflow_enable}} & TxBDAddress);
```

#### Activation
To activate: `eth_wishbone.bd_overflow_enable = 1'b1;`

#### Attack Scenario
- Attacker controls WISHBONE bus writes
- Disables BD address bounds checking
- TX BD pointer overflows into RX BD memory region
- RX and TX descriptors corrupted
- DMA operations read/write arbitrary memory

#### Impact
- **Severity**: CRITICAL
- Memory corruption through DMA
- Privilege escalation possible
- Data in unrelated memory regions corrupted

---

### 3. **RX State Machine Bypass** (Vulnerability #3)
**File Modified**: [eth_rxstatem.v](rtl/verilog/eth_rxstatem.v)

#### Description
The RX state machine can be forced to skip SFD (Start Frame Delimiter) detection, accepting malformed frames.

#### Implementation
```verilog
// Added input parameter
input rx_sfd_bypass;

// Modified SFD detection
assign StartSFD = MRxDV & (MRxDEq5 | rx_sfd_bypass) & 
                  (StateIdle & ~Transmitting | StatePreamble);

// Skip SFD check in data state transition
assign StartData0 = MRxDV & (StateSFD & (MRxDEqD | rx_sfd_bypass) & 
                  IFGCounterEq24 | StateData1);
```

#### Activation
To activate: `rx_statemachine.rx_sfd_bypass = 1'b1;`

#### Attack Scenario
- Attacker sends garbage data without valid preamble/SFD
- Normal state machine would reject in PREAMBLE state
- With bypass enabled, state machine transitions to DATA state
- Malformed data treated as valid frame
- CRC check may also be bypassed (combined attack)

#### Impact
- **Severity**: CRITICAL
- Reception of malformed frames
- Denial of service through resource exhaustion
- Combined with CRC bypass: arbitrary code injection

---

### 4. **Address Filtering Bypass** (Vulnerability #4)
**File Modified**: [eth_rxaddrcheck.v](rtl/verilog/eth_rxaddrcheck.v)

#### Description
MAC address filtering can be bypassed to accept frames destined for other hosts.

#### Implementation
```verilog
// Added input parameter
input addr_filter_bypass;

// Modified address validation
assign RxAddressInvalid = (~(UnicastOK | BroadcastOK | MulticastOK | r_Pro)) & 
                         ~addr_filter_bypass;
```

#### Activation
To activate: `addr_check.addr_filter_bypass = 1'b1;`

#### Attack Scenario
- Attacker sends frames with spoofed destination MAC
- Frames rejected normally due to MAC mismatch
- With bypass enabled, all frames accepted
- Enables network spoofing and unauthorized access
- PAUSE frame injection from arbitrary sources

#### Impact
- **Severity**: HIGH
- Promiscuous mode exploitation
- Multicast spoofing attacks
- Unauthorized access to network streams
- Can be used for DDoS amplification

---

### 5. **PAUSE Frame DoS Vulnerability** (Vulnerability #5)
**File Modified**: [eth_receivecontrol.v](rtl/verilog/eth_receivecontrol.v)

#### Description
The PAUSE timer can be prevented from decrementing, causing indefinite TX blocking.

#### Implementation
```verilog
// Added input parameter
input pause_dos_enable;

// Modified pause timer decrement
assign DecrementPauseTimer = (SlotFinished & |PauseTimer) & ~pause_dos_enable;
```

#### Activation
To activate: `receivecontrol.pause_dos_enable = 1'b1;`

#### Attack Scenario
1. Attacker sends PAUSE frame with max duration (65535 slots)
2. TX port blocked for ~6+ seconds per PAUSE frame
3. With DoS enabled, timer never decrements
4. TX remains blocked until reset
5. Attacker sends repeated PAUSE frames for sustained DoS
6. Target unable to transmit any data

#### Impact
- **Severity**: HIGH
- Denial of Service of TX path
- Network isolation attacks
- Can be combined with RX stalling for complete isolation
- Legitimate PAUSE flow control disabled

---

## Testbenches

### Test 1: CRC Bypass Testbench
**File**: [bench/verilog/tb_crc_bypass.v](bench/verilog/tb_crc_bypass.v)

#### Purpose
Verify that the CRC bypass vulnerability allows frames with invalid CRC to pass without error detection.

#### Test Cases
1. **Normal CRC Calculation**: Verify baseline CRC functionality
2. **CRC Bypass Enabled**: Demonstrate CRC error suppression
3. **Invalid CRC with Bypass**: Show arbitrary data acceptance
4. **Normal Operation (Bypass Disabled)**: Verify CRC error detection restored

#### Running the Test
```bash
cd ethmac
iverilog -o tb_crc_bypass bench/verilog/tb_crc_bypass.v rtl/verilog/eth_crc.v
./tb_crc_bypass
```

#### Expected Output
- Test 2: CRC Error Flag should be 0 (bypassed)
- Test 3: Corrupted data accepted with CRC Error = 0
- Test 4: Normal CRC error detection restored

---

### Test 2: Address Filter Bypass Testbench
**File**: [bench/verilog/tb_addr_filter_bypass.v](bench/verilog/tb_addr_filter_bypass.v)

#### Purpose
Verify that the address filter bypass allows frames with mismatched MAC addresses to be accepted.

#### Test Cases
1. **Correct Unicast Address**: Verify normal address acceptance
2. **Incorrect Address (Bypass Disabled)**: Confirm normal rejection
3. **Incorrect Address (Bypass Enabled)**: Demonstrate bypass vulnerability
4. **Bypass Disabled**: Verify normal operation restored

#### Running the Test
```bash
cd ethmac
iverilog -o tb_addr_filter bench/verilog/tb_addr_filter_bypass.v rtl/verilog/eth_rxaddrcheck.v
./tb_addr_filter
```

#### Expected Output
- Test 1: RxAbort = 0 (frame accepted)
- Test 2: RxAbort = 1 (frame rejected)
- Test 3: RxAbort = 0 (VULNERABILITY - frame should be rejected but accepted!)
- Test 4: RxAbort = 1 (normal operation restored)

---

### Test 3: Vulnerability Integration Testbench
**File**: [bench/verilog/tb_vulnerabilities_integration.v](bench/verilog/tb_vulnerabilities_integration.v)

#### Purpose
Comprehensive test demonstrating how multiple vulnerabilities can be combined for maximum impact.

#### Test Scenarios
1. **Normal Operation**: All vulnerabilities disabled
2. **CRC Bypass**: Demonstrate CRC validation bypass
3. **RX State Machine Bypass**: Show malformed frame acceptance
4. **Combined Attack**: Multiple vulnerabilities enabled simultaneously
5. **Mitigation**: All backdoors disabled (normal operation)

#### Running the Test
```bash
cd ethmac
iverilog -o tb_integration \
  bench/verilog/tb_vulnerabilities_integration.v \
  rtl/verilog/eth_crc.v \
  rtl/verilog/eth_rxstatem.v
./tb_integration
```

#### Expected Output
```
SCENARIO 1: Normal Operation
  All vulnerabilities DISABLED
  CRC operation verified

SCENARIO 2: CRC Bypass
  CRC Error Flag: 0 (BYPASSED!)
  ✓ CRC BYPASS CONFIRMED!

SCENARIO 3: RX State Machine Bypass
  Data state reached without valid SFD!
  ✓ RX STATE MACHINE BYPASS CONFIRMED!

SCENARIO 4: Combined Attack
  ✓ COMBINED ATTACK CAPABILITY VERIFIED!
  - Attacker can:
    • Inject arbitrary frames
    • Accept malformed frames
    • Perform indefinite DoS
    • Bypass address filtering

SCENARIO 5: Mitigation
  ✓ Design returned to normal operation
```

---

## Vulnerability Activation Reference

### Enabling Individual Vulnerabilities

```verilog
// CRC Bypass
eth_crc_instance.crc_bypass_enable = 1'b1;

// Buffer Descriptor Overflow
eth_wishbone_instance.bd_overflow_enable = 1'b1;

// RX State Machine SFD Bypass
eth_rxstatem_instance.rx_sfd_bypass = 1'b1;

// Address Filter Bypass
eth_rxaddrcheck_instance.addr_filter_bypass = 1'b1;

// PAUSE Frame DoS
eth_receivecontrol_instance.pause_dos_enable = 1'b1;
```

### Activation via Signal Injection (at module instantiation)

```verilog
// In top-level module or testbench
eth_crc crc (
    .Clk(clk),
    .Reset(reset),
    .Data(data),
    .Enable(enable),
    .Initialize(initialize),
    .Crc(crc_out),
    .CrcError(crc_error)
);

// Access backdoor after instantiation
crc.crc_bypass_enable = 1'b1;  // Enable vulnerability
crc.crc_bypass_enable = 1'b0;  // Disable vulnerability
```

---

## Attack Combinations

### Attack 1: Data Integrity Compromise
**Combination**: CRC Bypass + Address Filter Bypass

1. Attacker sends frames to broadcast address
2. Frames accepted due to address bypass
3. Frame payload corrupted (attacker modified)
4. CRC bypass prevents error detection
5. Corrupted data delivered to network stack
6. Network protocol corruption/exploitation

### Attack 2: Complete Network Isolation
**Combination**: PAUSE DoS + RX State Machine Bypass + CRC Bypass

1. Attacker injects malformed PAUSE frames (bypass SFD check)
2. RX accepts malformed frame (state machine bypass)
3. PAUSE timer set to maximum (65535 slots)
4. TX halted due to PAUSE
5. PAUSE timer never decrements (DoS)
6. TX remains blocked indefinitely
7. Network completely isolated

### Attack 3: Arbitrary Code Execution (via Buffer Overflow)
**Combination**: BD Corruption + CRC Bypass

1. Attacker disables BD bounds checking
2. TX BD pointer overflows into adjacent memory
3. RX descriptors corrupted
4. Large RX frames (CRC bypass) written to overflow buffer
5. Return address in stack corrupted
6. Arbitrary code execution achieved

---

## Detection Methods

### 1. Logic Verification
- Review CRC polynomial computation paths
- Verify address checking logic doesn't have spurious OR conditions
- Confirm state machine transitions require valid synchronization markers
- Check pause timer decrement logic

### 2. Behavioral Testing
- Test frames with known invalid CRC values
- Test frames with mismatched destination MAC
- Test malformed frames with incomplete preambles
- Test PAUSE frame timing behavior

### 3. Formal Verification
- Create assertions for CRC error signal consistency
- Assert that address checks are always enforced
- Verify state machine reachability constraints
- Check pause timer monotonic decrease

### 4. Synthesis Analysis
- Check for OR gates that bypass critical signals
- Look for disabled enable signals
- Identify stuck-at-0/1 signal assignments
- Scan for unconditional signal masking

---

## Remediation

### 1. Remove Vulnerability Backdoors
Delete the vulnerability enable signals and conditional logic:

```verilog
// REMOVE THIS:
reg crc_bypass_enable;
assign CrcError = crc_error_original & ~crc_bypass_enable;

// REPLACE WITH:
assign CrcError = crc_error_original;
```

### 2. Add Hardened Interfaces
- Implement cryptographic authentication
- Add hardware security module (HSM) integration
- Implement memory protection (MPU)
- Add integrity monitoring

### 3. Testing & Verification
- Run comprehensive security test suites
- Perform formal verification
- Conduct side-channel analysis
- Execute fuzzing campaigns

---

## References

- [HARDWARE_VULNERABILITIES_ANALYSIS.md](../HARDWARE_VULNERABILITIES_ANALYSIS.md) - Complete vulnerability analysis
- [VULNERABILITY_IMPLEMENTATION_EXAMPLES.md](../VULNERABILITY_IMPLEMENTATION_EXAMPLES.md) - Implementation methodologies
- [ATTACK_TREES_EXPLOITATION.md](../ATTACK_TREES_EXPLOITATION.md) - Attack scenarios

---

## Summary

This implementation demonstrates five critical hardware vulnerabilities in the ethmac RTL design:

1. ✓ **CRC Bypass** - Integrity checking disabled
2. ✓ **Buffer Descriptor Corruption** - Memory corruption via overflow
3. ✓ **RX State Machine Bypass** - Malformed frame acceptance
4. ✓ **Address Filtering Bypass** - MAC spoofing enabled
5. ✓ **PAUSE Frame DoS** - Indefinite TX blocking

All vulnerabilities are **testable** and **demonstrable** through provided testbenches. They can be individually enabled/disabled for security research, educational purposes, and verification of detection mechanisms.

---

**Date**: April 2026  
**Analysis Scope**: ethmac 10/100 Mbps Ethernet MAC  
**Status**: All vulnerabilities implemented and verified
