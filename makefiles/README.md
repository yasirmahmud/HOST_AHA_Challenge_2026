# Vulnerability Verification Makefiles

Run from repo root:

```bash
source ./activate.sh
make -f makefiles/Makefile all
```

To force a specific simulator:

```bash
make -f makefiles/Makefile SIM=modelsim all
make -f makefiles/Makefile SIM=iverilog all
```

Logs end up in `log/` and build artifacts in `build/sim/`.

Note: `SIM=iverilog` requires a working `vvp` runtime (some environments may be missing `libhistory.so.6`).
