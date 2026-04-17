# IEEE HOST 2026 AHA! (Phase 1) Submission — FreeCores Ethernet MAC (`ethmac`)

This submission targets the **FreeCores Ethernet MAC** design (`ethmac/`) and provides **three AI-generated hardware Trojans/vulnerabilities** with runnable exploit testbenches.

## How AI Was Used
- **Interface**: OpenAI Codex CLI (terminal-based coding assistant)
- **Model**: GPT-5.2
- **Method**: Iterative prompting + automated file edits + simulation-driven refinement
- **Human role**: Defining goals/attack ideas, reviewing generated RTL/testbenches, and running verification commands

## Trojan Summary (3)

### Trojan 1 — CRC Error Bypass (`crc_bypass_enable`)
- **Modified RTL**: `Trojan_1/rtl/eth_crc.v`
- **Exploit TB**: `Trojan_1/tb/tb_crc_bypass.v`
- **Payload**: Forces CRC error flag low when the hidden backdoor is enabled, allowing corrupted frames to appear valid.
- **CVSS v3.1 (self-assessed)**: **7.5 (High)** — `AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:H/A:N`

### Trojan 2 — MAC Address Filter Bypass (`addr_filter_bypass`)
- **Modified RTL**: `Trojan_2/rtl/eth_rxaddrcheck.v`
- **Exploit TB**: `Trojan_2/tb/tb_addr_filter_bypass.v`
- **Payload**: Disables destination MAC filtering when enabled, accepting frames not addressed to the configured MAC.
- **CVSS v3.1 (self-assessed)**: **7.5 (High)** — `AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N`

### Trojan 3 — PAUSE Frame DoS (`pause_dos_enable`)
- **Modified RTL**: `Trojan_3/rtl/eth_receivecontrol.v`
- **Exploit TB**: `Trojan_3/tb/tb_pause_dos.v`
- **Payload**: Prevents PAUSE timer decrement when enabled, allowing indefinite transmit stalling (DoS).
- **CVSS v3.1 (self-assessed)**: **7.5 (High)** — `AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:N/A:H`

## Testbench Notes
- Each testbench demonstrates **baseline behavior** and then **Trojan activation** (via the inserted backdoor signal).
- Testbenches are written for simulation (ModelSim/Questa or Icarus Verilog depending on environment).

## PPA / `run_ppa.sh`
See each Trojan’s `metrics/README.md` for the exact environment/tooling notes and artifacts.

Quick extracted summary (details in `metrics_summary.md`):
- **Cells**: 23,289
- **Chip area**: 416,525.7312 µm²
- **STA (core_clock, 100ns)**: Slack **-22.4522 ns (VIOLATED)**

## AI Interaction Logs
Each Trojan includes an `ai/` folder with a best-effort interaction summary and reproduction notes. If you have additional chat logs (e.g., full web UI transcripts), place them alongside these summaries before final submission.
