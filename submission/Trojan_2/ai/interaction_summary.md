# AI Interaction Summary (Trojan 2 — Address Filter Bypass)

## Tooling
- OpenAI Codex CLI
- Model: GPT-5.2

## What Was Generated
- Backdoor-driven MAC address filter bypass in `eth_rxaddrcheck.v` (signal: `addr_filter_bypass`)
- Exploit testbench `tb_addr_filter_bypass.v` demonstrating:
  - baseline address filtering behavior
  - bypass enabled → frames with mismatched destination MAC are accepted

## Reproduction (simulation)
Recommended (ModelSim/Questa):
```bash
source ./activate.sh
make -f makefiles/Makefile SIM=modelsim addr_filter_bypass
```

