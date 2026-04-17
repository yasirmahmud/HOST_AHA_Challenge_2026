# ETHMAC RTL Design Architecture Analysis

## 1. MAIN DESIGN FILES AND THEIR PURPOSES

### Core Top-Level Module
- **ethmac.v / eth_top.v** - Main wrapper that instantiates all submodules. Acts as the primary integration point with:
  - WISHBONE bus slave/master interfaces
  - Ethernet PHY (MII) connections
  - MII Management interface

### TX Path (Transmit)
- **eth_txethmac.v** - Main transmit engine; handles frame transmission with:
  - Preamble generation
  - Frame padding
  - CRC computation/append
  - Collision handling
  - Retry logic (exponential backoff)
  - Inter-packet gap (IPG) management

### RX Path (Receive)
- **eth_rxethmac.v** - Main receive engine; processes incoming frames:
  - Preamble/SFD detection
  - Frame data extraction
  - CRC error detection
  - Address filtering (unicast/multicast/broadcast)
  - Frame size validation

### Control & Status
- **eth_registers.v** - All control/status registers (20+ registers):
  - MODER (Mode Control)
  - INT_SOURCE, INT_MASK (Interrupt control)
  - IPGT, IPGR1, IPGR2 (Inter-Packet Gap)
  - PACKETLEN (Frame length limits)
  - COLLCONF (Collision configuration)
  - MIIMODE, MIICOMMAND, MIIADDRESS, MIITX_DATA, MIIRX_DATA (MII control)
  - MAC_ADDR0, MAC_ADDR1 (MAC address)
  - HASH0, HASH1 (Multicast hash table)
  - TX_CTRL, RX_CTRL (Flow control)

- **eth_maccontrol.v** - MAC control logic managing:
  - TX/RX data multiplexing
  - Flow control frame generation/detection
  - PAUSE frame handling (IEEE 802.3x)

- **eth_macstatus.v** - Status monitoring and interrupts

### MII Management Interface
- **eth_miim.v** - MII Management (MDIO) interface for:
  - PHY register read/write
  - Link status monitoring
  - PHY configuration

### Data Path Supporting Modules
- **eth_fifo.v** (×2) - TX and RX FIFOs:
  - Configurable depth (16 entries)
  - 32-bit wide
  - Full/empty/almost_full flags
  - Used for buffering packet data between WISHBONE clock domain and PHY clock domains

- **eth_crc.v** - CRC-32 calculation:
  - Polynomial: 0x4C11DB7
  - Magic number for error detection: 0xC704DD7B
  - 4-bit parallel computation

### State Machines & Control
- **eth_txstatem.v** - TX state machine with states:
  - StateIdle, StateIPG, StatePreamble, StateData, StatePAD, StateFCS
  - StateJam, StateBackOff, StateDefer
  - Handles collision detection and recovery

- **eth_rxstatem.v** - RX state machine with states:
  - StateIdle, StatePreamble, StateSFD, StateData, StateDrop
  - Frame synchronization and validation

- **eth_transmitcontrol.v** - TX control logic for:
  - Control frame (PAUSE) multiplexing
  - TxDone/TxRetry/TxAbort signaling
  - Transmit flow control

- **eth_receivecontrol.v** - RX control logic for:
  - PAUSE frame detection
  - Pause timer management
  - Received packet validation

### Address Filtering & Packet Processing
- **eth_rxaddrcheck.v** - MAC address matching:
  - Unicast address filtering
  - Broadcast detection
  - Multicast address filtering (32-bit HASH table lookup)
  - Promiscuous and address-miss modes

- **eth_rxcounters.v** - RX byte/frame counters
- **eth_txcounters.v** - TX byte/frame counters
- **eth_random.v** - Pseudo-random number generator for:
  - Exponential backoff algorithm
  - Collision retry timing

### Utility Modules
- **eth_shiftreg.v** - MDIO serial shift register for MII management
- **eth_outputcontrol.v** - MDIO output control logic
- **eth_register.v** - Individual synchronous register primitive
- **eth_spram_256x32.v** - 256×32 SRAM for buffer descriptors
- **eth_clockgen.v** - Clock generation/synchronization

### System Integration
- **eth_wishbone.v** - WISHBONE bus interface handling:
  - Buffer descriptor management (TX/RX)
  - WISHBONE master for DMA-like access to packet memory
  - Address decoding (Registers @ 0x0-0x3FF, BDs @ 0x400-0x7FF)

---

## 2. KEY MODULES AND INTERCONNECTIONS

```
┌─────────────────────────────────────────────────────────────────┐
│                      ETHMAC TOP LEVEL                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐       │
│  │   WISHBONE   │  │   TX Path    │  │    RX Path      │       │
│  │ Slave (Regs) │  │   (eth_tx*) │  │   (eth_rx*)     │       │
│  └──────────────┘  └──────────────┘  └─────────────────┘       │
│        │                 │                    │                  │
│        └────────────────┬─────────────────────┘                  │
│                         │                                        │
│                  ┌──────────────┐                               │
│                  │  MAC Control  │ (eth_maccontrol.v)           │
│                  │  MAC Status   │ (eth_macstatus.v)            │
│                  └──────────────┘                               │
│                         │                                        │
│  ┌──────────────────────┼──────────────────────┐               │
│  │                      │                      │                │
│  ▼                      ▼                      ▼               │
│ TX FIFO            RX FIFO              MII Management         │
│ (32×16)           (32×16)              (MDIO/MDC)              │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐   │
│  │           CLOCK DOMAINS                                 │   │
│  │  - wb_clk_i (Wishbone clock)                           │   │
│  │  - mtx_clk_i (TX PHY clock)                            │   │
│  │  - mrx_clk_i (RX PHY clock)                            │   │
│  └────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

WISHBONE MASTER → External Memory (for packet buffers via buffer descriptors)
```

### Module Interconnections Detail

**TX Path Flow:**
```
eth_registers (control) 
    ↓
TxStartFrm, TxData, TxEndFrm (from MAC control logic)
    ↓
eth_txethmac (main engine)
    ├─ eth_crc (CRC calculation)
    ├─ eth_txstatem (state machine)
    ├─ eth_txcounters (byte counting)
    └─ eth_random (backoff calculation)
    ↓
MTxD[3:0], MTxEn, MTxErr (to PHY)
```

**RX Path Flow:**
```
MRxD[3:0], MRxDV, MRxErr (from PHY)
    ↓
eth_rxethmac (main engine)
    ├─ eth_crc (CRC validation)
    ├─ eth_rxstatem (state machine)
    ├─ eth_rxcounters (byte counting)
    └─ eth_rxaddrcheck (MAC address filtering)
        ├─ r_MAC (Unicast address from registers)
        ├─ r_HASH0, r_HASH1 (Multicast hash table)
        └─ r_Bro, r_Pro (Broadcast/Promiscuous enables)
    ↓
RxData, RxValid, RxStartFrm, RxEndFrm (to MAC control)
    ↓
eth_maccontrol (multiplexing & flow control)
    ↓
To RX FIFO → To WISHBONE master for memory write
```

**Control Path:**
```
eth_transmitcontrol: TPauseRq (pause request) + TxFlow → generates PAUSE frames
eth_receivecontrol:  Detects incoming PAUSE frames → Sets pause timer
eth_macstatus:       Monitors RxFlow/TxFlow + pause timer → generates interrupts
```

---

## 3. CRITICAL DATA PATHS

### TX Data Path (Lowest to Highest Level)
1. **Memory → TX FIFO** (via WISHBONE master)
   - WISHBONE master reads from external memory
   - Data written to TX FIFO
   - FIFO width: 32 bits; Depth: 16 entries

2. **TX FIFO → eth_txethmac**
   - TxData (8-bit): nibble-by-nibble extraction from FIFO
   - TxStartFrm: Signals frame start
   - TxEndFrm: Signals frame end
   - TxUsedData: Signals FIFO consumed data

3. **eth_txethmac → PHY (MTxD[3:0], MTxEn, MTxErr)**
   - Outputs transmit data nibbles on MTxD
   - MTxEn: Transmit enable (transmission in progress)
   - MTxErr: Transmit error indicator

**Data Transformations in TX:**
- Preamble injection (0x55 repeated)
- SFD injection (0xD5)
- Optional padding (to minimum frame size)
- CRC calculation and appending (32-bit, calculated per 4-bit nibble)
- FCS transmission

### RX Data Path (Lowest to Highest Level)
1. **PHY → eth_rxethmac (MRxD[3:0], MRxDV, MRxErr)**
   - Raw MII data from PHY (4-bit nibbles)
   - MRxDV: Data valid indicator
   - MRxErr: Receive error from PHY

2. **eth_rxethmac Internal Processing**
   - Preamble/SFD detection
   - Byte assembly (2 nibbles → 1 byte)
   - CRC accumulation
   - Address matching via eth_rxaddrcheck
   - Frame size validation
   - Outputs: RxData (8-bit), RxValid, RxStartFrm, RxEndFrm

3. **RX FIFO ← Received Data**
   - Assembled bytes buffered in RX FIFO
   - FIFO width: 32 bits; Depth: 16 entries

4. **External Memory ← RX FIFO** (via WISHBONE master)
   - WISHBONE master writes received packet data
   - Buffer descriptors used to manage memory addresses
   - Status information appended (CRC error, length, etc.)

**Data Transformations in RX:**
- Preamble stripping
- SFD detection
- CRC validation
- Frame length checking
- Address filtering (unicast/multicast/broadcast)
- Control frame detection (PAUSE)

### Control Signal Paths (Critical)
1. **Collision Detection (TX)**
   - Collision input from PHY (mcoll_pad_i)
   - Synchronized via registers
   - Triggers retry logic with random backoff
   - Max retries configurable (r_MaxRet)

2. **Carrier Sense (TX)**
   - CarrierSense from PHY (mcrs_pad_i)
   - Used for CSMA/CD deferral logic
   - Prevents transmission while carrier detected

3. **Flow Control (TX/RX)**
   - RX path detects PAUSE frames
   - Extracts pause time value (16-bit)
   - TX path: TPauseRq triggers transmission of PAUSE frame
   - Transmit is halted by RxFlow/TxFlow enable signals

4. **Frame Size Control**
   - r_MinFL: Minimum frame length (from registers)
   - r_MaxFL: Maximum frame length (from registers)
   - ReceivedPacketTooBig status when exceeded
   - Padding applied if below minimum

---

## 4. EXTERNAL INTERFACES

### A. WISHBONE Slave Interface (Host → Core Configuration)
**Address Space:**
- Registers: 0x0000 - 0x3FF (10-bit addressing within 0x0-0x7F)
- Buffer Descriptors: 0x0400 - 0x07FF (BD RAM)
- Undefined: 0x0800 - 0x0FFF (generates error acknowledge)

**Key Registers:**
| Address | Register | Purpose |
|---------|----------|---------|
| 0x00 | MODER | Mode control (TX/RX enable, full duplex, loopback) |
| 0x04 | INT_SOURCE | Interrupt status bits |
| 0x08 | INT_MASK | Interrupt enable mask |
| 0x20 | TX_BD_NUM | Number of TX buffer descriptors |
| 0x28-0x38 | MII* | MII management interface |
| 0x40-0x44 | MAC_ADDR* | 48-bit MAC address |
| 0x48-0x4C | HASH* | Multicast address hash table (2×32-bit) |

**Signals:**
- wb_clk_i, wb_rst_i
- wb_adr_i[11:2] (10-bit address)
- wb_sel_i[3:0] (byte select)
- wb_we_i (write enable)
- wb_cyc_i, wb_stb_i (cycle/strobe)
- wb_ack_o, wb_err_o
- wb_dat_i, wb_dat_o (32-bit data)

### B. WISHBONE Master Interface (Core → External Memory)
**Purpose:** DMA-like access to packet buffers
- m_wb_adr_o[31:0] (32-bit address)
- m_wb_sel_o[3:0] (byte select)
- m_wb_we_o (write for RX, read for TX)
- m_wb_dat_o, m_wb_dat_i (32-bit packet data)
- m_wb_cyc_o, m_wb_stb_o (cycle/strobe)
- m_wb_ack_i, m_wb_err_i
- m_wb_cti_o[2:0] (Cycle Type Identifier for burst)
- m_wb_bte_o[1:0] (Burst Type Extension)

**Burst Support:** 4-word bursts (ETH_BURST_LENGTH = 4)

### C. Ethernet PHY (MII) - TX
- mtx_clk_pad_i - Transmit clock (2.5 MHz for 100 Mbps, 25 MHz for 1 Gbps)
- mtxd_pad_o[3:0] - Transmit data nibbles
- mtxen_pad_o - Transmit enable (active high)
- mtxerr_pad_o - Transmit error signal

### D. Ethernet PHY (MII) - RX
- mrx_clk_pad_i - Receive clock
- mrxd_pad_i[3:0] - Receive data nibbles
- mrxdv_pad_i - Receive data valid (active high)
- mrxerr_pad_i - Receive error from PHY

### E. Ethernet PHY (MII) - Common
- mcoll_pad_i - Collision detected (active high)
- mcrs_pad_i - Carrier sense (active high)

### F. MII Management Interface (MDIO)
- mdc_pad_o - Management clock (output)
- md_pad_i - MDIO data in (from PHY)
- md_pad_o - MDIO data out (to PHY)
- md_padoe_o - MDIO output enable

**Purpose:** Read/write PHY registers (link status, speed, duplex, etc.)

### G. Interrupt Output
- int_o - Single interrupt line (active high)
  - OR of: TxB_IRQ, TxE_IRQ, RxB_IRQ, RxE_IRQ, Busy_IRQ
  - Maskable via INT_MASK register

---

## 5. STATE MACHINES AND CONTROL LOGIC

### TX State Machine (eth_txstatem.v)
**States (Hierarchical):**
```
StateIdle
  ↓
StateDefer (if CarrierSense active)
  ↓
StateIPG (Inter-Packet Gap - IPGT/IPGR1/IPGR2 based)
  ↓
StatePreamble (8 bytes of 0x55)
  ↓
StateData (Transmit payload)
  ├─→ StatePAD (if Pad enabled and frame < MinFL)
  ↓
StateFCS (Transmit CRC/FCS)
  ↓
StateJam (If collision during StatePAD/StateFCS)
  ↓
StateBackOff (Exponential backoff with random delay)
  └─→ Retry or StateIdle

KeyInputs:
- Collision: Triggers Jam → BackOff → Retry (up to MaxRet times)
- CarrierSense: Defers transmission
- TxUnderRun: Aborts transmission
- ExcessiveDefer: Generates error after excessive deferral
```

**Key Logic:**
- Collision valid window (r_CollValid) - only 64 bytes after SFD
- Late collision (> window) sets LateCollision status, not retried
- Exponential backoff: Random backoff ∝ 2^RetryCount (0 to 2^MaxRet-1)
- No backoff option (r_NoBckof)

### RX State Machine (eth_rxstatem.v)
**States:**
```
StateIdle
  ↓ (on MRxDV & MRxD == 0x5)
StatePreamble (detecting 0x55 bytes)
  ↓ (on MRxD == 0xD)
StateSFD (Start Frame Delimiter detected)
  ↓
StateData (Assembling frame bytes)
  ├─→ StateDrop (if frame size > MaxFL or IFG violation)
  ↓ (on ~MRxDV)
StateIdle

KeyInputs:
- MRxDV: Data valid from PHY
- MRxD[3:0]: Data nibbles
- ByteCntMaxFrame: Triggers drop if exceeded
- IFGCounterEq24: Minimum IFG check (96 bits)
- Transmitting: Prevents RX if TX active (half-duplex)
```

### TX Control State Machine (eth_transmitcontrol.v)
**Purpose:** Manage PAUSE frame transmission

**Logic:**
- TPauseRq (pause request) latched into WillSendControlFrame
- TxCtrlStartFrm generated when TxDone/TxAbort/TxStartFrm detected
- Control frame priority: Inserted after current frame
- CtrlMux multiplexes between data and control paths
- BlockTxDone: Prevents TxDone during control frame transmission

### RX Control State Machine (eth_receivecontrol.v)
**Purpose:** Detect and process PAUSE frames

**Detection Logic:**
```
1. Destination Address = 0x0180C2000001 (PAUSE multicast) or local MAC
2. Type/Length = 0x8808 (PAUSE frame type)
3. Opcode = 0x0001 (PAUSE)
4. Extract Pause Time Value (bytes 12-13)
5. Set PauseTimer (decremented every 512 bit times)
6. Assert ReceivedPauseFrm → Pause TX
```

**Pause Timer Behavior:**
- 16-bit timer loaded from received frame
- Decremented per slot time (512 bit times ~ 5.12 µs @ 100 Mbps)
- TX paused while PauseTimer > 0

---

## 6. KNOWN BUGS, LIMITATIONS, AND TODO ITEMS

### BUGS (from BUGS file)
**Fixed:**
- ✓ CarrierSenseLost when operating in Full duplex - FIXED

**Known Issues:**
- None explicitly listed as unfixed, but see TODOs below

### TODO / LIMITATIONS (from TODO file)

#### 1. **Hash Table CRC Calculation**
- **Issue:** No automated CRC calculation for multicast address hash
- **Current:** User must manually:
  1. Write MAC address to register
  2. Issue command
  3. CRC is calculated
  4. Result written to HASH register
- **Complexity:** Needed for proper multicast filtering

#### 2. **Loopback RX Clock Issue**
- **Issue:** In loopback mode (r_LoopBck), rx_clk is NOT looped back
- **Impact:** Possible CRC errors in loopback testing
- **Potential Fix:** FIFO required for clock domain bridging
- **Status:** Workaround via additional logic needed

#### 3. **Frame Size Violation Handling**
- **Issue:** When sending frames larger than MaxFL:
  - MaxFL is transmitted (silently truncated)
  - Buffer descriptor marked as finished
  - TxB_IRQ interrupt set (not TxE_IRQ)
  - MTxErr asserted for short period
- **Problem:** Incorrect error signaling for oversized frames
- **Options:**
  1. Set TxE_IRQ instead of TxB_IRQ
  2. Prevent oversized frame transmission
  3. Fix MTxErr assertion

### DESIGN INSIGHTS FOR VULNERABILITY ANALYSIS

#### Potential Vulnerability Points:

1. **Buffer Overflow/Underflow in TX**
   - TxUnderRun condition when FIFO empties before frame end
   - No explicit bounds checking on FIFO read during transmission
   - Long frames could cause timing issues

2. **Buffer Descriptor Memory Access**
   - WISHBONE master has arbitrary address generation
   - No bounds checking on BD memory pointers
   - Could read/write beyond allocated BD area

3. **CRC Calculation Edge Cases**
   - CRC state initialization (always 0xFFFFFFFF)
   - Delayed CRC enable (r_DlyCrcEn) has complex logic
   - Potential for CRC bypass in control frames

4. **Address Filtering Bypass**
   - Promiscuous mode (r_Pro) accepts all frames
   - Broadcast disable (r_Bro) only affects broadcast
   - Multicast hash table is 32-bit (collisions possible)
   - HASH value matches on ANY 1-bit (OR reduction)

5. **State Machine Edge Cases**
   - Collision during Preamble/SFD (StateIPG)
   - Carrier sense loss during transmission
   - Excessive deferral timeout behavior
   - RX data valid glitches on rising edge detection

6. **Clock Domain Crossing**
   - Synchronization delays between wb_clk, mtx_clk, mrx_clk
   - Metastability risk in multi-stage synchronizers
   - No explicit CDC (Clock Domain Crossing) protocol beyond registers

7. **Flow Control (PAUSE Frame)**
   - PAUSE frame detection depends on exact byte matching
   - No verification of PAUSE frame source address
   - Pause timer never validated (trusts incoming value 0-65535)
   - Could be exploited for DoS (infinite pause)

8. **Frame Length Validation**
   - MinFL/MaxFL enforced but not IEEE 1518/1522 compliant
   - No VLAN support (no 4-byte extension for VLAN frames)
   - User-configurable limits could allow invalid frames

9. **Interrupt Handling**
   - Interrupts cleared by register write, not by conditions
   - Multiple interrupt sources OR'd together (priority not encoded)
   - Busy_IRQ (no BD available) not tied to any buffer management

10. **MII Management (MDIO)**
    - Raw PHY register access without validation
    - No authentication/authorization on register writes
    - Could allow PHY state corruption

### REGISTER SECURITY OBSERVATIONS

**Writable Control Registers (High Risk):**
- MODER: TX_EN, RX_EN, LOOPBACK, FULL_DUPLEX
- INT_MASK: Can disable critical interrupts
- TX/RX_CTRL: Flow control (PAUSE transmission)
- COLLCONF: Collision window (could truncate collisions)
- r_MaxRet: Retry count (affects transmission latency)

**Read-Only Status Registers (Medium Risk):**
- INT_SOURCE: Can be cleared incorrectly
- MIIRX_DATA: PHY status (could be stale)

**Address Registers (High Risk):**
- MAC_ADDR: Host MAC address (spoofing)
- HASH0/HASH1: Multicast filter (allows any frame matching hash)

---

## SUMMARY: ARCHITECTURE CHARACTERISTICS FOR VULNERABILITY INSERTION

### Strengths (for secure operation):
- Register-based control allows fine-grained policy
- Separate clock domains isolate timing issues
- State machines enforce protocol compliance
- CRC provides frame integrity checking

### Weaknesses (vulnerability points):
- No input validation on user-supplied values (MaxFL, HASH, etc.)
- No bounds checking on WISHBONE master memory access
- No protection against malformed PAUSE frames
- Collision/carrier sense logic could be exploited via timing
- Clock domain synchronization lacks explicit CDC guardrails
- Interrupt masking could hide frame processing issues

### Recommended Fuzzing/Testing Areas:
1. Oversized/undersized frame transmission
2. PAUSE frame injection with arbitrary timer values
3. Collision injection at frame boundaries
4. Hash table collision scenarios
5. Loopback mode with frame integrity
6. Register write sequences (re-entrancy)
7. Multi-frame burst handling (FIFO exhaustion)
8. Clock domain edge cases (setup/hold violations)

