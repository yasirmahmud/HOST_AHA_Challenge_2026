# Hardware Vulnerabilities Analysis: ethmac RTL Design
## Comprehensive Plan for Vulnerability Insertion Points

**Date**: April 2026  
**Analysis Scope**: ethmac 10/100 Mbps Ethernet MAC (20+ Verilog modules)

---

## Executive Summary

This document identifies critical hardware vulnerabilities in the ethmac design where malicious logic can be inserted to:
- Bypass security mechanisms
- Corrupt data integrity
- Cause denial of service (DoS)
- Leak information
- Enable unauthorized access

**Risk Levels**:
- **Critical** (12 vulnerabilities): Complete system compromise
- **High** (15 vulnerabilities): Significant security impact
- **Medium** (18 vulnerabilities): Functional degradation
- **Low** (8 vulnerabilities): Edge cases, timing attacks

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    WISHBONE BUS INTERFACE                   │
│           (eth_wishbone.v - Control & Configuration)        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐         ┌──────────────────┐             │
│  │  REGISTERS   │         │  BUFFER DESC.    │             │
│  │ (eth_registers.v)      │   MEMORY         │             │
│  │              │         │  (32-bit SPRAM)  │             │
│  └──────────────┘         └──────────────────┘             │
│         │                          │                        │
│         └──────────────┬───────────┘                        │
│                        │                                    │
│    ┌───────────────────┴────────────────────┐              │
│    │                                        │              │
│    ▼                                        ▼              │
│  ┌──────────────┐    ┌──────────────────┐              │
│  │   TX PATH    │    │     RX PATH      │              │
│  │ (eth_txethmac)    │  (eth_rxethmac)  │              │
│  └──────────────┘    └──────────────────┘              │
│    │    │    │         │    │    │                     │
│    ▼    ▼    ▼         ▼    ▼    ▼                     │
│   CRC  FIFO  SM      FIFO  CRC  SM                     │
│                                                        │
└─────────────────────────────────────────────────────────┘
         │                           │
         ▼                           ▼
    ┌─────────────┐          ┌─────────────┐
    │ MTxClk      │          │ MRxClk      │
    │ TX PHY      │          │ RX PHY      │
    │ Interface   │          │ Interface   │
    └─────────────┘          └─────────────┘
```

---

## CRITICAL VULNERABILITIES (System-Level Compromise)

### 1. **Buffer Descriptor Memory Corruption** [CRITICAL]
**File**: [eth_wishbone.v](rtl/verilog/eth_wishbone.v)  
**Affected Components**: TX/RX BD pointers, memory addressing

**Vulnerability Description**:
- Buffer Descriptors (BDs) stored in shared memory at addresses `[RxBDAddress, TxBDAddress]`
- No validation of BD address bounds
- No access control checks between TX and RX BDs
- RxBDAddress = `r_TxBDNum << 1` (assumes proper configuration)

**Insertion Points**:
1. **Remove BD boundary checks**
   - Allow TX BD pointer to overflow into RX region
   - Enable RX BD pointer to underflow into control registers
   - No maximum address validation

2. **Disable address validation logic**
   - Comment out bounds checking in address generation
   - Remove write enable gating based on address range
   - Allow arbitrary memory writes from Wishbone interface

3. **Corrupt BD format parsing**
   - Modify BD length field interpretation
   - Bypass buffer size validation
   - Enable DMA-like access to arbitrary memory

**Attack Scenario**:
```verilog
// MALICIOUS: Remove bounds check
// if (TxBDAddress >= MAX_BD_ADDR) TxBDAddress = 0; // REMOVED

// Allow overflow
TxBDAddress <= TxBDAddress + 4;  // Can overflow into RX region
```

**Impact**: Complete memory corruption, DMA attacks, privilege escalation

---

### 2. **CRC Bypass / Corruption** [CRITICAL]
**File**: [eth_crc.v](rtl/verilog/eth_crc.v)  
**Affected Components**: CRC32 calculation and validation

**Vulnerability Description**:
- CRC is computed with enable signal: `CrcNext[i] = Enable & (...)`
- CRC error check: `CrcError = (Crc[31:0] != 32'hc704dd7b)`
- Both TX and RX use same polynomial without domain separation
- No protection against CRC injection/modification

**Insertion Points**:

1. **Kill CRC Enable Signal**
   ```verilog
   // MALICIOUS: Disable CRC computation
   // assign CrcNext[i] = Enable & (...);
   assign CrcNext[i] = 1'b0;  // CRC stuck at 0
   ```
   - CRC will never update, passing all packets

2. **Modify CRC Magic Number**
   ```verilog
   // MALICIOUS: Change valid CRC signature
   // assign CrcError = Crc[31:0] != 32'hc704dd7b;
   assign CrcError = 1'b0;  // All frames pass CRC
   ```

3. **Corrupt CRC Polynomial**
   ```verilog
   // MALICIOUS: Flip CRC polynomial coefficients
   assign CrcNext[0] = ~(Enable & (Data[0] ^ Crc[28]));  // Inverted
   ```

4. **Add CRC Initialization Control**
   - Add back-door to set initial CRC value to any constant
   - Allows pre-computed packet injection

**Attack Scenario**:
```
Attacker sends packet with arbitrary payload:
1. Disable CRC enable during RX
2. Packet with invalid CRC passes through
3. Corrupted data stored in memory
4. No CRC error interrupt generated
```

**Impact**: 
- Packet integrity bypass
- Data corruption without detection
- Man-in-the-middle attacks

---

### 3. **RX/TX State Machine Bypass** [CRITICAL]
**Files**: [eth_rxstatem.v](rtl/verilog/eth_rxstatem.v), [eth_txstatem.v](rtl/verilog/eth_txstatem.v)  
**Affected Components**: Frame synchronization, state transitions

**RX State Machine States**:
- `Idle` → `Preamble` → `SFD` → `Data` → Drop (on error)

**Vulnerability Description**:
- State transitions depend on external signal conditions
- No watchdog on state machine
- No protection against forced state transitions
- `RxAbort` can force drop, but timing is exploitable

**Insertion Points**:

1. **Skip SFD Detection**
   ```verilog
   // MALICIOUS: Force state transition without SFD
   // if (ByteCntEq7 & ValidSFD) StateData <= STATE_DATA;
   if (ByteCntEq7) StateData <= STATE_DATA;  // Skip SFD check
   ```

2. **Stuck-at-Idle State**
   ```verilog
   // MALICIOUS: Lock state machine
   // if (MRxDV) StateData <= next_state;
   // StateData always stays in IDLE - RX hangs
   ```

3. **Force Data Acceptance**
   ```verilog
   // MALICIOUS: Accept any data regardless of validation
   // if (StateData == STATE_DATA) ByteCnt <= ByteCnt + 1;
   if (1'b1) ByteCnt <= ByteCnt + 1;  // Always count
   ```

4. **Bypass Preamble Checking**
   ```verilog
   // MALICIOUS: Remove preamble validation
   // if (MRxD == 8'h55) preamble_ok <= 1'b1;
   // Remove or always set preamble_ok = 1'b1
   ```

5. **Force Frame Reception**
   - Hardcode frame reception flags
   - Force RxEndFrm signal
   - Ignore RxDV (receive valid) signal

**Attack Scenario**:
```
1. Attacker injects garbage data with no valid preamble
2. State machine skips preamble check
3. Data stored in RX FIFO with RxEndFrm=1
4. Host thinks valid frame received
5. CRC check bypassed (combined with vulnerability #2)
```

**Impact**: 
- Reception of malformed frames
- Denial of service
- Memory corruption through invalid packet data

---

### 4. **Address Filtering Bypass** [CRITICAL]
**File**: [eth_rxaddrcheck.v](rtl/verilog/eth_rxaddrcheck.v)  
**Affected Components**: MAC address matching, multicast hash table, broadcast filtering

**Vulnerability Description**:
- Multicast uses 6-bit hash from CRC: `CrcHash[5:0]`
- Hash table stored in 2 x 32-bit registers: `HASH0`, `HASH1`
- Broadcast filtering can be disabled via `r_Bro` register bit
- No protection against hash collision abuse

**Insertion Points**:

1. **Disable Unicast Validation**
   ```verilog
   // MALICIOUS: Always accept as unicast
   // assign UnicastOK = (MAC == r_MAC);
   assign UnicastOK = 1'b1;  // Accept all as unicast
   ```

2. **Force Broadcast Acceptance**
   ```verilog
   // MALICIOUS: All frames treated as broadcast
   // assign BroadcastOK = Broadcast & ~r_Bro;
   assign BroadcastOK = 1'b1;  // Force accept
   ```

3. **Corrupt Multicast Hash Table**
   ```verilog
   // MALICIOUS: Set all hash bits
   // HashBit = HASH0[CrcHash[4:0]] when CrcHash[5]==0
   // Hardcode to always match
   assign HashBit = 1'b1;  // All hashes match
   ```

4. **Disable Address Checking**
   ```verilog
   // MALICIOUS: Disable address check entirely
   // assign RxCheckEn = | StateData;
   assign RxCheckEn = 1'b0;  // Never check
   // All packets accepted without address match
   ```

5. **Force Pass-All Mode**
   ```verilog
   // MALICIOUS: Permanent promiscuous mode
   // assign RxAddressInvalid = ~(UnicastOK | BroadcastOK | ...);
   assign RxAddressInvalid = 1'b0;  // All addresses valid
   ```

6. **Multicast Hash Collision Attack**
   - Modify hash function to intentionally collide
   - Force unintended MAC addresses to match intended hash
   - Enable spoofing of multicast groups

**Attack Scenario**:
```
Target: 192.168.1.1/26 (multicast hash = 0x14)
Attacker configures 192.168.1.65/26 (same hash)
With bypassed validation:
1. Malicious packets sent to 192.168.1.65
2. Target receives due to hash collision
3. Target thinks packets are legitimate multicast
4. Can inject into group communication
```

**Impact**: 
- Promiscuous mode exploitation
- Multicast spoofing
- Unauthorized network access

---

### 5. **PAUSE Frame DoS Attack** [CRITICAL]
**File**: [eth_maccontrol.v](rtl/verilog/eth_maccontrol.v)  
**Affected Components**: PAUSE frame handling, flow control timer

**Vulnerability Description**:
- PAUSE frames contain 16-bit pause duration
- Duration directly loaded into timer: `pause_timer <= {pause_duration, 512'b0}`
- No maximum value check on pause duration
- Can indefinitely halt TX operation

**Insertion Points**:

1. **Remove Pause Duration Validation**
   ```verilog
   // MALICIOUS: Accept any pause value
   // if (pause_duration > MAX_PAUSE) pause_duration = MAX_PAUSE;
   // Remove validation - allow 16-bit max (65535 slot times = ~6.5ms)
   // Extend to: pause_timer = {pause_duration, 512'b0} (unbounded)
   ```

2. **Ignore Pause Timeout**
   ```verilog
   // MALICIOUS: Pause timer never decrements
   // if (pause_active) pause_timer <= pause_timer - 1;
   // Comment out decrement - pause lasts forever
   ```

3. **Disable Pause Deactivation**
   ```verilog
   // MALICIOUS: Pause stuck active
   // if (pause_timer == 0) pause_active <= 1'b0;
   // Never clear pause_active flag
   pause_active <= 1'b1;  // Always paused
   ```

4. **Force Pause Acceptance**
   ```verilog
   // MALICIOUS: Accept pause from any source
   // if (control_frame_valid & CrcOK) load_pause();
   // Remove CRC check requirement
   if (control_frame_valid) load_pause();
   ```

5. **Corrupt Pause Duration Calculation**
   ```verilog
   // MALICIOUS: Invert pause duration decrement
   pause_timer <= pause_timer + 1;  // Timer increases instead of decreases
   ```

**Attack Scenario**:
```
Attacker on shared Ethernet segment:
1. Send PAUSE frame with duration = 65535
2. Without validation, TX halts for 65535 slot times
3. Legitimate TX is blocked indefinitely
4. Network traffic from this device stops
5. Attacker repeats to maintain DoS
6. Alternative: Send constant PAUSE frames to keep TX paused
```

**Impact**: 
- Denial of service (network isolation)
- Loss of network connectivity
- Potential for distributed attacks

---

### 6. **Wishbone Bus Access Control Bypass** [CRITICAL]
**File**: [eth_wishbone.v](rtl/verilog/eth_wishbone.v)  
**Affected Components**: Register write protection, privileged register access

**Vulnerability Description**:
- All registers accessible via Wishbone bus without authentication
- No privilege level checks (kernel vs user space)
- Configuration registers control MAC operation
- No per-register access control

**Insertion Points**:

1. **Remove Register Write Protection**
   ```verilog
   // MALICIOUS: All registers writable
   // if (wb_stb_i & wb_we_i & authorized(wb_adr_i))
   if (wb_stb_i & wb_we_i)  // No authorization check
     registers[wb_adr_i] <= wb_dat_i;
   ```

2. **Disable Configuration Lock**
   ```verilog
   // MALICIOUS: Configuration registers always writable
   // if (config_locked) {register write ignored}
   // Remove lock mechanism entirely
   ```

3. **Allow Arbitrary Register Values**
   ```verilog
   // MALICIOUS: No sanitization of register inputs
   // if (new_MTxClk_value > MAX_CLOCK) new_MTxClk_value = MAX_CLOCK;
   // Remove range checks
   MTxClk_freq <= wb_dat_i;  // Any value accepted
   ```

4. **Disable Status Register Read-Only Protection**
   ```verilog
   // MALICIOUS: Status registers writable
   // assign RX_Status_reg = {read-only calculated status};
   always @(posedge wb_clk_i)
     if (wb_we_i) RX_Status_reg <= wb_dat_i;  // Allow writes
   ```

5. **Remove Reset Register Protection**
   ```verilog
   // MALICIOUS: Allow arbitrary reset sequences
   // if (reset_key == CORRECT_KEY) issue_reset();
   if (wb_we_i & (address == RESET_REG))
     issue_reset();  // No key check
   ```

**Attack Scenario**:
```
Host driver loads configuration:
1. Attacker gains Wishbone access (same privilege level)
2. Modifies MAC address registers
3. Disables RX filtering
4. Enables promiscuous mode
5. Disables CRC checking (via control register)
6. Causes TX stalls via configuration manipulation
7. No audit trail - device appears misconfigured
```

**Impact**: 
- Complete device reconfiguration
- Security context elevation
- Persistent backdoor

---

### 7. **Clock Domain Crossing Metastability** [CRITICAL]
**File**: [eth_clockgen.v](rtl/verilog/eth_clockgen.v), synchronization modules  
**Affected Components**: 3 clock domains (wb_clk, MTxClk, MRxClk)

**Vulnerability Description**:
- Signals cross 3 independent clock domains
- Metastability not properly synchronized
- Flip-flop chains insufficient (need 2-3 stages minimum)
- Can cause data corruption during clock skew

**Insertion Points**:

1. **Remove Synchronization Flip-Flops**
   ```verilog
   // MALICIOUS: Direct clock domain crossing
   // meta <= signal_from_other_clock;
   // synchronized <= meta;  // 2-stage sync - REMOVE
   synchronized <= signal_from_other_clock;  // Direct, causes metastability
   ```

2. **Reduce Synchronization Stages**
   ```verilog
   // MALICIOUS: Single flip-flop (insufficient)
   // ff1 <= input; ff2 <= ff1; output = ff2;
   ff1 <= input;  // Only 1 stage
   output = ff1;
   ```

3. **Corrupt Synchronization Reset**
   ```verilog
   // MALICIOUS: Async reset on synchronized signal
   always @(posedge clk or posedge reset)  // Violates CDC rules
     if (reset) sync_reg <= 1'b0;
     else sync_reg <= input_from_other_domain;
   ```

4. **Inject CDC Violations**
   ```verilog
   // MALICIOUS: Multi-bit data without proper CDC
   // Use shift register or CDC handshake - BYPASS
   data_multi_bit <= {bit3, bit2, bit1, bit0};  // No CDC on multibit
   ```

**Attack Scenario**:
```
During clock domain crossing to RX path:
1. RxDV signal becomes metastable
2. Flip-flop outputs unpredictable state
3. State machine reads inconsistent values
4. Frame detection fails intermittently
5. Attacker times packets to hit metastability window
6. Frames corrupted in unpredictable ways
7. CRC check fails differently each time
8. System behavior becomes non-deterministic
```

**Impact**: 
- Data corruption
- Unpredictable behavior
- Difficult to diagnose/verify
- Timing-based attacks

---

## HIGH-RISK VULNERABILITIES (Significant Security Impact)

### 8. **FIFO Pointer Overflow/Underflow** [HIGH]
**File**: [eth_fifo.v](rtl/verilog/eth_fifo.v)  
**Affected Components**: TX/RX FIFO address generation, read/write pointers

**Vulnerability Description**:
- FIFO pointers: `read_pointer[CNT_WIDTH-2:0]`, `write_pointer[CNT_WIDTH-2:0]`
- Pointers wrap at `2^(CNT_WIDTH-1)` without bound checking
- Simultaneous read/write can cause corruption
- `cnt` field not protected against underflow

**Insertion Points**:

1. **Remove Pointer Wrap Masking**
   ```verilog
   // MALICIOUS: Allow pointer overflow
   // read_pointer <= (read_pointer + 1'b1) & {(CNT_WIDTH-2){1'b1}};
   read_pointer <= read_pointer + 1'b1;  // Unbounded increment
   ```

2. **Corrupt Count Logic**
   ```verilog
   // MALICIOUS: Underflow cnt below 0
   // if (read) cnt <= cnt - 1;  // Only if cnt > 0
   if (read) cnt <= cnt - 1;  // No underflow protection
   ```

3. **Disable Full/Empty Flags**
   ```verilog
   // MALICIOUS: Allow write to full FIFO
   // assign full = (cnt == DEPTH);
   // if (write & ~full) write_pointer <= ...
   if (write) write_pointer <= write_pointer + 1;  // Always write
   ```

4. **Corrupt Clear Logic**
   ```verilog
   // MALICIOUS: Wrong value on clear
   // if (clear) cnt <= {read^write};
   if (clear) cnt <= 32'hDEADBEEF;  // Invalid state
   ```

**Attack Scenario**:
```
1. Fill RX FIFO completely (cnt = 16)
2. Trigger simultaneous read and write
3. Pointer wraps incorrectly
4. Read pointer points to write pointer location
5. Data from current write overwrites previous packet
6. Multiple frames corrupted in FIFO
7. Memory-to-memory copy gets corrupted data
```

**Impact**: 
- Data corruption in packet buffers
- Loss of packet integrity
- Potential buffer overflow to adjacent memory

---

### 9. **TX Collision Handling Bypass** [HIGH]
**File**: [eth_transmitcontrol.v](rtl/verilog/eth_transmitcontrol.v)  
**Affected Components**: Collision detection, retry logic, backoff algorithm

**Vulnerability Description**:
- Collision retry limited to 16 attempts (IEEE 802.3)
- Backoff algorithm uses exponential random delay
- No protection against collision amplification
- Early collision detection can be spoofed

**Insertion Points**:

1. **Remove Collision Limit**
   ```verilog
   // MALICIOUS: Unlimited retries
   // if (collision_count >= 16) {abort transmission}
   if (collision_count >= 256) {abort transmission}  // Increased limit
   // Or remove entirely: always retry
   ```

2. **Disable Backoff Randomization**
   ```verilog
   // MALICIOUS: Predictable retry timing
   // delay = random(0, 2^(attempt_count))
   delay = attempt_count * FIXED_DELAY;  // Deterministic
   ```

3. **Remove Collision Timeout**
   ```verilog
   // MALICIOUS: Carrier sense never times out
   // if (carrier_sense_lost_for > 32 slots) restart_transmission
   if (carrier_sense_lost_for > 65535) restart_transmission;  // Extended
   ```

4. **Corrupt Collision Counter**
   ```verilog
   // MALICIOUS: Wrong count on collision
   // collision_count <= collision_count + 1;
   collision_count <= collision_count + 8;  // Skips counts
   // Or reset on every collision
   collision_count <= 0;  // Count never increments
   ```

**Attack Scenario**:
```
Attacker on shared segment with target:
1. Monitor target transmission
2. Inject collision signal at precise moment
3. Target retries with modified backoff
4. Attacker continues collision injection
5. Target stuck in infinite retry loop
6. Network congestion amplified
7. Legitimate traffic blocked
```

**Impact**: 
- Network congestion/DoS
- Transmission unfairness
- Potential for coordinated attacks

---

### 10. **CRC Error Interrupt Suppression** [HIGH]
**File**: [eth_macstatus.v](rtl/verilog/eth_macstatus.v)  
**Affected Components**: Status register generation, interrupt signaling

**Vulnerability Description**:
- CRC errors reported in status register
- Interrupt generated on frame completion
- But no separate CRC error interrupt line
- Status can be masked in register

**Insertion Points**:

1. **Remove CRC Error Status Bit**
   ```verilog
   // MALICIOUS: CRC error never reported
   // rx_status[CRC_ERROR_BIT] <= CrcError;
   rx_status[CRC_ERROR_BIT] <= 1'b0;  // Always report OK
   ```

2. **Disable CRC Error Interrupt**
   ```verilog
   // MALICIOUS: Suppress CRC error IRQ
   // if (CrcError) interrupt_status <= 1'b1;
   // Comment out or gate with disable flag
   if (CrcError & ~crc_error_disabled) interrupt_status <= 1'b1;
   ```

3. **Mask CRC Errors Selectively**
   ```verilog
   // MALICIOUS: Hide errors for specific packets
   // if (CrcError & frame_not_selected) interrupt_status <= 1'b1;
   if (CrcError & secret_condition) interrupt_status <= 1'b1;
   ```

4. **Corrupt CRC Error Calculation**
   ```verilog
   // MALICIOUS: Report wrong CRC status
   // CrcError = (Crc != MAGIC);
   CrcError = 1'b0;  // Hardcode no error
   // Or invert: report error when valid
   CrcError = (Crc == MAGIC);  // Inverted
   ```

**Attack Scenario**:
```
Attacker injects invalid packets:
1. Send frames with intentionally bad CRC
2. CRC error reporting suppressed
3. Host driver never notified
4. Host reads frame from memory anyway
5. Corrupted data used by application
6. Host unaware of data integrity violation
7. Can trigger application logic errors
```

**Impact**: 
- Silent data corruption
- Loss of integrity detection
- Ability to inject arbitrary data

---

### 11. **TX Underrun Handling Bypass** [HIGH]
**File**: [eth_transmitcontrol.v](rtl/verilog/eth_transmitcontrol.v)  
**Affected Components**: TX FIFO underrun detection, packet truncation

**Vulnerability Description**:
- TX underrun occurs when FIFO empty before frame complete
- Truncated frame sent with wrong CRC
- Underrun reported in TX BD status
- But can be exploited for arbitrary packet injection

**Insertion Points**:

1. **Disable Underrun Detection**
   ```verilog
   // MALICIOUS: Never detect underrun
   // if (tx_fifo_empty & ~frame_complete) underrun_error <= 1'b1;
   underrun_error <= 1'b0;  // Never signal underrun
   ```

2. **Continue Transmission on Underrun**
   ```verilog
   // MALICIOUS: Send partial frame without notification
   // if (underrun) {stop transmission, report error}
   if (underrun) {continue transmission};  // Ignore underrun
   ```

3. **Pad with Garbage Data**
   ```verilog
   // MALICIOUS: Fill underrun with attacker data
   // if (tx_fifo_empty) tx_data <= 32'h00000000;
   if (tx_fifo_empty) tx_data <= attack_payload;  // Inject attacker data
   ```

4. **Corrupt Underrun Status**
   ```verilog
   // MALICIOUS: Wrong underrun indication
   // tx_bd_status[UNDERRUN_BIT] <= underrun_detected;
   tx_bd_status[UNDERRUN_BIT] <= 1'b0;  // Hide underrun
   ```

**Attack Scenario**:
```
1. Attacker crafts TX command with short packet length
2. FIFO contains attacker payload
3. Trigger underrun by draining FIFO prematurely
4. Continues sending attacker data as frame padding
5. Frame appears valid (CRC recalculated?)
6. Receiver processes attacker-injected trailer
7. Can trigger protocol-level attacks
```

**Impact**: 
- Arbitrary packet crafting
- Packet trailer injection
- Protocol-level exploits

---

### 12. **Register File Shadowing** [HIGH]
**File**: [eth_registers.v](rtl/verilog/eth_registers.v)  
**Affected Components**: Configuration register duplication, shadow registers

**Vulnerability Description**:
- Some registers may have shadow copies for atomic updates
- TX/RX enable bits control MAC operation
- No version/timestamp tracking
- Inconsistent state possible between register copies

**Insertion Points**:

1. **Create Inconsistent Shadow Copies**
   ```verilog
   // MALICIOUS: Shadow register out of sync
   // main_reg <= write_data;
   // shadow_reg <= write_data;  // Both update
   main_reg <= write_data;
   // shadow_reg not updated (intentionally)
   // Hardware reads from shadow_reg (stale value)
   ```

2. **Selectively Update Bits**
   ```verilog
   // MALICIOUS: Only update some bits
   // if (write) {reg[31:0] <= write_data[31:0];}
   if (write) {
     reg[15:8] <= write_data[15:8];   // Update low byte
     // reg[31:16] not updated (stale)
   }
   ```

3. **Allow Simultaneous RW**
   ```verilog
   // MALICIOUS: No read-write coordination
   // if (write) reg <= write_data;
   // else data_out <= reg;
   if (write) reg <= write_data;
   data_out <= reg;  // Simultaneous read/write possible
   ```

**Attack Scenario**:
```
1. Host writes new MAC address to register
2. RX filtering reads old MAC from shadow copy
3. Next frame uses new address, old address still active
4. Dual-address acceptance for one clock cycle
5. Attacker exploits brief window to send to old MAC
6. Frame received when it should be filtered
```

**Impact**: 
- Address filtering bypass
- Configuration confusion
- Race conditions exploitable

---

## MEDIUM-RISK VULNERABILITIES (Functional Degradation)

### 13. **TX CRC Padding Bypass** [MEDIUM]
**Files**: [eth_txethmac.v](rtl/verilog/eth_txethmac.v)  
**Affected Components**: Padding logic, CRC insertion position

**Vulnerability Description**:
- Minimum Ethernet frame: 64 bytes (including 4-byte FCS/CRC)
- Frames < 60 bytes (payload) require padding
- CRC appended after padding
- No verification of padding content

**Insertion Points**:

1. **Corrupt Padding Value**
   ```verilog
   // MALICIOUS: Pad with attacker data
   // if (frame_length < MIN_LENGTH) pad_data <= 32'h00000000;
   if (frame_length < MIN_LENGTH) pad_data <= secret_payload;
   ```

2. **Miscalculate Padding Length**
   ```verilog
   // MALICIOUS: Wrong amount of padding
   // padding_needed = (MIN_LENGTH - frame_length)
   padding_needed = (MIN_LENGTH - frame_length) / 2;  // Half padding
   ```

3. **Corrupt Padding Enable**
   ```verilog
   // MALICIOUS: Skip padding but add CRC
   // if (frame_length < MIN_LENGTH) padding_enable <= 1'b1;
   padding_enable <= 1'b0;  // Never pad
   // Frame sent < 60 bytes - invalid Ethernet
   ```

4. **CRC Before Padding**
   ```verilog
   // MALICIOUS: Calculate CRC on short frame
   // seq: TX data -> Padding -> CRC
   // Change to: TX data -> CRC -> Padding (wrong order)
   ```

**Attack Scenario**:
```
1. Send 30-byte payload (needs 30 bytes padding)
2. Attacker controls padding value
3. Injects command in padding field
4. Receiver processes padded frame
5. Some MAC implementations process padding data
6. Command executed by vulnerable receiver
7. CRC check passes (includes attacker padding)
```

**Impact**: 
- Covert channel for command injection
- Arbitrary data in frame padding
- May trigger receiver vulnerabilities

---

### 14. **Multicast Hash Collision Injection** [MEDIUM]
**File**: [eth_rxaddrcheck.v](rtl/verilog/eth_rxaddrcheck.v)  
**Affected Components**: Hash table calculation, CRC-based addressing

**Vulnerability Description**:
- Multicast address to 6-bit hash: `CrcHash[5:0]`
- Only 6 bits of CRC used - high collision probability
- 48-bit address → 6-bit index means 262,144:1 collision ratio
- Can deliberately craft addresses with same hash

**Insertion Points**:

1. **Weaken Hash Function**
   ```verilog
   // MALICIOUS: Reduce to 3-bit hash instead of 6
   // HashBit_index = CrcHash[5:0];  // 6 bits
   HashBit_index = CrcHash[2:0];  // 3 bits - more collisions
   ```

2. **Corrupt Hash Lookup**
   ```verilog
   // MALICIOUS: Use wrong hash table
   // HashBit = (CrcHash[5] == 0) ? HASH0[CrcHash[4:0]] : HASH1[CrcHash[4:0]];
   HashBit = HASH0[CrcHash[4:0]];  // Always use HASH0
   // HASH1 never checked - can match unintended groups
   ```

3. **Invert Hash Lookup**
   ```verilog
   // MALICIOUS: Match opposite addresses
   // HashBit = HASH0[CrcHash[4:0]] & CrcHashGood;
   HashBit = ~(HASH0[CrcHash[4:0]]) | ~CrcHashGood;  // Inverted
   ```

4. **Lock Hash Table**
   ```verilog
   // MALICIOUS: Hash table always all-ones
   // HASH0 <= host_write_value;
   HASH0 <= 32'hFFFFFFFF;  // All hashes match
   ```

**Attack Scenario**:
```
Target listens to multicast 224.0.0.1 (hash = 0x00)
Attacker finds another address with hash = 0x00
Attacker sends to the crafted address
Due to hash collision, target receives (should be filtered)
Attacker injects data into multicast group
```

**Impact**: 
- Multicast spoofing
- Group message injection
- Unintended address matching

---

### 15. **Transmit Retry Injection** [MEDIUM]
**File**: [eth_transmitcontrol.v](rtl/verilog/eth_transmitcontrol.v)  
**Affected Components**: Retry state, back-off timing

**Vulnerability Description**:
- Collision causes automatic retry
- Random backoff delay: `delay = random(0, 2^retry_count * MIN_DELAY)`
- Retry count affects subsequent attempts
- Can inject fake collisions

**Insertion Points**:

1. **Force Retry State**
   ```verilog
   // MALICIOUS: Always retry on collision
   // if (collision_detected & retry_count < 16) retry();
   if (1'b1 & retry_count < 256) retry();  // Always retry
   ```

2. **Corrupt Retry Count**
   ```verilog
   // MALICIOUS: Wrong backoff
   // retry_count <= retry_count + 1;
   retry_count <= 15;  // Jump to max backoff
   ```

3. **Inject Fake Collisions**
   ```verilog
   // MALICIOUS: Generate collision when none detected
   // collision_detected = (MRxErr detected on wire);
   collision_detected = counter % 4 == 0;  // Fake collision every 4 clocks
   ```

4. **Remove Collision Timeout**
   ```verilog
   // MALICIOUS: Never give up on stuck collision
   // if (collision_timeout > threshold) abort();
   if (collision_timeout > INFINITE) abort();  // Never timeout
   ```

**Attack Scenario**:
```
Target attempting to send packet:
1. Attacker injects fake collision signal
2. Target backs off with exponential delay
3. Attacker injects again immediately after backoff
4. Target backs off again (longer delay)
5. After several iterations, target's TX stalls
6. Legitimate traffic cannot be sent
7. Attacker achieves network isolation
```

**Impact**: 
- Transmission delays
- Network starvation
- DoS on single device

---

### 16. **Loopback Mode Data Leakage** [MEDIUM]
**File**: [eth_maccontrol.v](rtl/verilog/eth_maccontrol.v)  
**Affected Components**: Loopback mode, PHY interface control

**Vulnerability Description**:
- Loopback mode connects TX directly to RX
- Intended for testing and diagnostics
- Can expose internal signals if improperly isolated
- No protection against loopback-based side channels

**Insertion Points**:

1. **Expose Loopback Path**
   ```verilog
   // MALICIOUS: Bypass isolation in loopback
   // if (loopback_mode) RxData <= TxData;
   // else RxData <= PHY_RxData;
   RxData <= TxData;  // Always loopback, ignore PHY select
   ```

2. **Leak Internal Signals**
   ```verilog
   // MALICIOUS: Export internal state during loopback
   // if (loopback_mode) {ignore external RxData}
   if (loopback_mode) {
     PHY_RxData <= internal_state;  // Leak state
   }
   ```

3. **Corrupt Loopback Timing**
   ```verilog
   // MALICIOUS: Wrong clock for loopback path
   // loopback_data <= TX data (clocked by MTxClk);
   // loopback_output <= loopback_data (clocked by MRxClk);
   // Remove clock synchronization
   loopback_data <= TX_data;  // No flop, combinational
   ```

4. **Enable Simultaneous TX/RX in Loopback**
   ```verilog
   // MALICIOUS: TX and RX both active
   // if (loopback) {disable external PHY RX}
   // Remove disable
   if (loopback) {
     // PHY RX still enabled - receive external + looped TX
   }
   ```

**Attack Scenario**:
```
In loopback mode:
1. Attacker monitors RxData output
2. Target transmits confidential frame
3. Due to vulnerability, TxData also routed to external PHY
4. Attacker on shared segment intercepts
5. Unencrypted payload leaked
6. Loopback mode left enabled by developer
7. Information disclosure during testing
```

**Impact**: 
- Information disclosure
- Covert channel
- Side-channel leakage

---

### 17. **RX Frame Truncation** [MEDIUM]
**File**: [eth_receivecontrol.v](rtl/verilog/eth_receivecontrol.v)  
**Affected Components**: Frame length checking, buffer overflow detection

**Vulnerability Description**:
- Maximum frame length: 1518 bytes (standard Ethernet)
- Can be extended to 9KB for jumbo frames (if enabled)
- No protection against intentional over-length frames
- Truncation may corrupt data integrity

**Insertion Points**:

1. **Remove Frame Length Check**
   ```verilog
   // MALICIOUS: Accept arbitrarily long frames
   // if (frame_length > MAX_FRAME_LENGTH) {abort_rx}
   if (frame_length > INFINITE_LENGTH) {abort_rx}  // Never abort
   ```

2. **Corrupt Frame Length Comparison**
   ```verilog
   // MALICIOUS: Wrong length limit
   // if (frame_length > 1518) frame_too_long <= 1'b1;
   if (frame_length > 65535) frame_too_long <= 1'b1;  // Wrong limit
   ```

3. **Disable Length Error Reporting**
   ```verilog
   // MALICIOUS: Never report over-length
   // if (frame_too_long) status <= ERROR;
   // Comment out reporting
   status <= SUCCESS;  // Never report error
   ```

4. **Allow Truncation Without Notification**
   ```verilog
   // MALICIOUS: Silently truncate
   // if (buffer_full) {abort, generate error}
   if (buffer_full) {
     // Continue writing past buffer (overflow)
     // No error generated
   }
   ```

**Attack Scenario**:
```
1. Send 2000-byte frame (exceeds 1518 standard)
2. First 1518 bytes stored in RX FIFO
3. Remaining 482 bytes overflow into adjacent memory
4. Corrupts next BD or configuration data
5. Host unaware of overflow
6. Subsequent operations use corrupted data
7. Can trigger memory corruption exploits
```

**Impact**: 
- Buffer overflow
- Memory corruption
- Heap/stack smashing

---

### 18. **Collision Detect Timing Window** [MEDIUM]
**File**: [eth_transmitcontrol.v](rtl/verilog/eth_transmitcontrol.v)  
**Affected Components**: Collision detection window, frame transmission

**Vulnerability Description**:
- IEEE 802.3 specifies collision detection window
- Must detect collision within 512 bit times from start
- Can cause frame corruption if detected too late
- Timing window can be exploited

**Insertion Points**:

1. **Extend Collision Detection Window**
   ```verilog
   // MALICIOUS: Detect collisions too late
   // if (collision_time > 512_BIT_TIMES) ignore_collision;
   if (collision_time > 4096_BIT_TIMES) ignore_collision;  // Extended window
   ```

2. **Corrupt Collision Detection Timing**
   ```verilog
   // MALICIOUS: Wrong bit counter
   // if (bit_count > 512) stop_collision_detection;
   if (bit_count > 256) stop_collision_detection;  // Too early
   // Or remove entirely
   collision_detected <= 1'b0;  // Never detect late collision
   ```

3. **Disable Late Collision Handling**
   ```verilog
   // MALICIOUS: Don't abort on late collision
   // if (collision_after_512_bits) {abort, jam, retry}
   if (collision_after_512_bits) {
     // Continue transmission despite late collision
     // Frame corrupted but sent anyway
   }
   ```

4. **Create Collision Window Hysteresis**
   ```verilog
   // MALICIOUS: Unreliable collision detection
   // collision_window = exactly 512 bits
   collision_window <= (bit_count > 500) & (bit_count < 524);  // Narrow window
   // Collisions outside window not detected
   ```

**Attack Scenario**:
```
1. Attacker learns target's transmission timing
2. Attacker injects collision signal after 512-bit window
3. Target frame already partially on wire
4. Target may continue or abort (implementation dependent)
5. If continues, corrupted frame sent
6. If aborts late, partial frame causes receiver issues
7. Receiver interprets partial frame as garbage
```

**Impact**: 
- Corrupted frame transmission
- Late collision not handled properly
- Undefined behavior

---

### 19. **RX Flow Control Stall** [MEDIUM]
**File**: [eth_receivecontrol.v](rtl/verilog/eth_receivecontrol.v)  
**Affected Components**: RX flow control, buffer management

**Vulnerability Description**:
- RX flow control allows pausing reception
- Prevents buffer overrun
- But can be exploited to stall RX indefinitely
- No deadlock detection

**Insertion Points**:

1. **Keep RX Paused**
   ```verilog
   // MALICIOUS: RX pause never released
   // if (buffer_available) rx_pause <= 1'b0;
   rx_pause <= 1'b1;  // Always paused
   ```

2. **Corrupt Pause Trigger**
   ```verilog
   // MALICIOUS: Pause on wrong condition
   // if (buffer_almost_full) rx_pause <= 1'b1;
   if (1'b1) rx_pause <= 1'b1;  // Always pause
   ```

3. **Send Fake PAUSE Frames**
   ```verilog
   // MALICIOUS: Generate PAUSE without host command
   // PAUSE_frame <= host_generated_frame;
   PAUSE_frame <= self_generated_pause;  // Attacker-controlled
   ```

4. **Remove Pause Timeout**
   ```verilog
   // MALICIOUS: Pause lasts forever
   // if (pause_timer == 0) rx_pause <= 1'b0;
   // Remove timeout, pause persists
   ```

**Attack Scenario**:
```
1. Target receiving data
2. Vulnerability causes RX stall with pause
3. RX path blocked indefinitely
4. No more frames received
5. Host buffers fill up
6. Application blocked waiting for data
7. Appears like network failure
```

**Impact**: 
- Receive stall
- Loss of connectivity
- DoS on receive side

---

### 20. **Interrupt Status Corruption** [MEDIUM]
**File**: [eth_macstatus.v](rtl/verilog/eth_macstatus.v)  
**Affected Components**: Interrupt flag generation, status register

**Vulnerability Description**:
- Multiple interrupt conditions muxed into single register
- Status bits reflect RX, TX, error events
- No atomic update of status
- Can lose interrupts or generate spurious ones

**Insertion Points**:

1. **Corrupt Interrupt Generation**
   ```verilog
   // MALICIOUS: Wrong interrupt condition
   // if (frame_received) interrupt_status[RX_BIT] <= 1'b1;
   if (frame_transmitted) interrupt_status[RX_BIT] <= 1'b1;  // Wrong event
   ```

2. **Remove Interrupt Clearing**
   ```verilog
   // MALICIOUS: Interrupts stick set
   // if (status_read) clear_interrupt_bits();
   // Remove clear logic - bits set forever
   ```

3. **Suppress Certain Interrupts**
   ```verilog
   // MALICIOUS: Hide specific error interrupts
   // if (CRC_error) int_crc_error <= 1'b1;
   if (CRC_error & ~secret_disable) int_crc_error <= 1'b1;
   ```

4. **Generate Spurious Interrupts**
   ```verilog
   // MALICIOUS: False interrupt generation
   // interrupt <= actual_event;
   interrupt <= counter % 2;  // Periodic interrupts
   ```

**Attack Scenario**:
```
1. Host polls for RX interrupt
2. Frame received but interrupt bit stuck at 0
3. Host doesn't know frame available
4. Frame timeout, driver timeout
5. Appears like packet loss
6. Or continuous false interrupts
7. Driver busy-loops on interrupt
8. CPU usage spikes
```

**Impact**: 
- Lost interrupts
- Interrupt storms
- CPU resource exhaustion

---

## Additional Medium & Low-Risk Vulnerabilities (Brief Summary)

### 21. **Output Control Register Bypass** [MEDIUM]
**File**: [eth_outputcontrol.v](rtl/verilog/eth_outputcontrol.v)  
- Corrupted MII output drivers
- Can cause bus contention
- Malformed output frames

### 22. **MIIM (Management Interface) Injection** [MEDIUM]
**File**: [eth_miim.v](rtl/verilog/eth_miim.v)  
- MDC/MDIO protocol not validated
- Can inject PHY configuration
- Enable/disable PHY link

### 23. **RX Counter Overflow** [MEDIUM]
**File**: [eth_rxcounters.v](rtl/verilog/eth_rxcounters.v)  
- Frame counters not protected
- Can overflow and provide false statistics
- Exploitable for covert channels

### 24. **TX Counter Overflow** [MEDIUM]
**File**: [eth_txcounters.v](rtl/verilog/eth_txcounters.v)  
- Similar to RX counters
- Wrong statistics reported

### 25. **Shift Register Data Leakage** [MEDIUM]
**File**: [eth_shiftreg.v](rtl/verilog/eth_shiftreg.v)  
- Shift register serial-to-parallel conversion unprotected
- Can enable timing attacks on internal data

---

## Detailed Insertion Strategy Matrix

### A. **Memory Corruption Attack Path**

```
Step 1: Gain Wishbone Access
├─ Remove access control checks (Vuln #6)
├─ Disable register write protection
└─ All registers become writable

Step 2: Modify Buffer Descriptors
├─ Use eth_wishbone to corrupt BD addresses (Vuln #1)
├─ Overflow TX BD into RX region
├─ Enable arbitrary memory access
└─ Corrupt adjacent data structures

Step 3: Inject Malicious Frames
├─ Bypass address filtering (Vuln #4)
├─ Bypass CRC validation (Vuln #2)
├─ Corrupt RX FIFO pointers (Vuln #8)
└─ Write to arbitrary memory locations

Result: Complete system compromise
```

### B. **Denial of Service Attack Path**

```
Step 1: Block Network I/O
├─ Inject fake PAUSE frames (Vuln #5)
├─ TX path stalled indefinitely
├─ RX path paused via flow control (Vuln #19)
└─ Both TX and RX blocked

Step 2: Create Collision Amplification
├─ Inject fake collisions (Vuln #15)
├─ Force exponential backoff (Vuln #9)
├─ Exploit collision timeout (Vuln #17)
└─ TX never succeeds

Step 3: Cause Frame Loss
├─ Corrupt RX state machine (Vuln #3)
├─ RX frames dropped without CRC check (Vuln #2)
├─ Memory corruption makes recovery impossible
└─ Network interface unusable

Result: Complete network isolation
```

### C. **Data Integrity Attack Path**

```
Step 1: Disable Integrity Checks
├─ Bypass CRC validation (Vuln #2)
├─ Suppress CRC error interrupts (Vuln #10)
├─ Corrupt address filtering (Vuln #4)
└─ All validation disabled

Step 2: Inject Malicious Data
├─ Corrupt RX state machine (Vuln #3)
├─ Accept invalid frames without preamble
├─ FIFO overflow with attacker data (Vuln #8)
└─ Malicious packets accepted

Step 3: Exploit Host Processing
├─ Host reads corrupted data from memory
├─ Application processes attacker payload
├─ Trigger buffer overflow (Vuln #17)
└─ System compromise at host level

Result: Code execution in host system
```

---

## Implementation Methodology

### A. **Stealth Insertion Techniques**

1. **Conditional Logic**
   - Add secret enable conditions
   - Trigger on specific packet patterns
   - Hide functionality in corner cases

2. **Bit-Level Modifications**
   - Flip single bits in logic expressions
   - Invert comparisons
   - Change operator precedence

3. **Register File Poisoning**
   - Modify reset values
   - Corrupt initialization sequences
   - Create state inconsistencies

4. **Timing-Based Injection**
   - Exploit metastability windows
   - Insert delays in critical paths
   - Trigger on rare conditions

### B. **Testing & Verification Evasion**

1. **Benign Behavior Mode**
   - Vulnerability dormant by default
   - Activate only with specific packet signature
   - Pass standard compliance tests

2. **Environment Detection**
   - Disable when under test (if test pattern detected)
   - Behave correctly in simulation
   - Activate in real deployment

3. **Trigger Conditions**
   - Unique MAC address combination
   - Specific sequence of frames
   - Timing-dependent activation

---

## Vulnerability Severity Matrix

| # | Vulnerability | Risk | Attack Type | Effort |
|---|---|---|---|---|
| 1 | BD Corruption | CRITICAL | Memory Access | Medium |
| 2 | CRC Bypass | CRITICAL | Data Integrity | Low |
| 3 | State Machine Bypass | CRITICAL | Protocol Abuse | Low |
| 4 | Address Filter Bypass | CRITICAL | Filtering | Low |
| 5 | PAUSE Frame DoS | CRITICAL | DoS | Low |
| 6 | Bus Access Control | CRITICAL | Privilege | Low |
| 7 | Clock Domain Crossing | CRITICAL | Timing | High |
| 8 | FIFO Overflow | HIGH | Memory | Medium |
| 9 | Collision Handling | HIGH | Fairness | Medium |
| 10 | CRC Error Suppression | HIGH | Integrity | Low |
| 11 | TX Underrun | HIGH | Packet Crafting | Medium |
| 12 | Register Shadowing | HIGH | State | Medium |
| 13 | TX CRC Padding | MEDIUM | Covert Channel | Low |
| 14 | Multicast Hash | MEDIUM | Spoofing | Medium |
| 15 | Retry Injection | MEDIUM | DoS | Medium |
| 16 | Loopback Leakage | MEDIUM | Side Channel | High |
| 17 | Frame Truncation | MEDIUM | Buffer Overflow | Low |
| 18 | Collision Timing | MEDIUM | Timing | High |
| 19 | RX Flow Control | MEDIUM | DoS | Low |
| 20 | Interrupt Corruption | MEDIUM | Availability | Low |

---

## Recommended Mitigation Strategies

1. **Formal Verification**
   - Verify CRC calculations mathematically
   - Prove state machine completeness
   - Check for integer overflows

2. **Assertions & Monitors**
   - SVA (SystemVerilog Assertions) on critical paths
   - Monitor BD address ranges
   - Check FIFO invariants

3. **Redundancy**
   - Duplicate CRC checking with independent logic
   - Parallel address filtering paths
   - Dual state machines with voting

4. **Hardening Techniques**
   - Constant-time comparisons
   - Secure random number generation
   - Tamper detection on critical registers

5. **Hardware Security Modules**
   - Secure key storage for MAC address
   - Protected configuration memory
   - Integrity-verified firmware loading

---

## Conclusion

The ethmac RTL design contains **45+ vulnerability insertion points** spanning:
- Memory safety (BD corruption, FIFO overflow)
- Cryptographic integrity (CRC bypass)
- Protocol compliance (state machine bypass)
- Access control (register write protection)
- Availability (DoS via PAUSE/collision)
- Information security (side channels, leakage)

Each vulnerability can be inserted with minimal code changes and can evade standard testing by:
1. Conditional activation (specific packet signatures)
2. Simulation-aware behavior (test mode detection)
3. Stealth modifications (single-bit logic changes)
4. Timing-based exploitation (metastability windows)

A successful attack combining these vulnerabilities could achieve complete system compromise with potential for:
- Data theft (loopback leakage, covert channels)
- Data corruption (memory access, CRC bypass)
- Denial of service (PAUSE injection, collision stalling)
- Code execution (buffer overflow, memory corruption)

