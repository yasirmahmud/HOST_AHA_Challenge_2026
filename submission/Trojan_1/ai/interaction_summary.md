# AI Interaction Summary (Trojan 1 — CRC Bypass)

## Tooling
- OpenAI Codex CLI
- Model: GPT-5.2

## What Was Generated
- Backdoor-driven CRC error suppression in `eth_crc.v` (signal: `crc_bypass_enable`)
- Exploit testbench `tb_crc_bypass.v` demonstrating:
  - baseline CRC error behavior
  - CRC bypass enabled → error flag suppressed

## Reproduction (simulation)
Recommended (ModelSim/Questa):
```bash
source ./activate.sh
make -f makefiles/Makefile SIM=modelsim crc_bypass
```

