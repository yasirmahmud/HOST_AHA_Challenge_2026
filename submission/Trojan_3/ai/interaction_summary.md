# AI Interaction Summary (Trojan 3 — PAUSE DoS)

## Tooling
- OpenAI Codex CLI
- Model: GPT-5.2

## What Was Generated
- Backdoor-driven PAUSE timer freeze in `eth_receivecontrol.v` (signal: `pause_dos_enable`)
- Exploit testbench `tb_pause_dos.v` demonstrating:
  - baseline PauseTimer decrement
  - pause_dos_enable asserted → PauseTimer no longer decrements (DoS condition)

## Reproduction (simulation)
Recommended (ModelSim/Questa):
```bash
source ./activate.sh
make -f makefiles/Makefile SIM=modelsim pause_dos
```

