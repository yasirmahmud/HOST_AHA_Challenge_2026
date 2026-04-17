# Extracted PPA Metrics Summary (ethmac)

Clock constraint used by `eth_synth/run_ppa.sh` / `eth_synth/grade_timing.sta`: **100.0 ns (10 MHz)**.

## Trojan 1 — CRC Error Bypass

Sources:
- `Trojan_1/metrics/ppa/area_report.txt`
- `Trojan_1/metrics/ppa/sta_report.txt`
- `Trojan_1/metrics/ppa/timing_report.txt`

Extracted:
- **Cells**: 23,289
- **Chip area**: 416,525.7312 µm²
- **Sequential area**: 309,708.2848 µm² (74.36%)
- **Longest topological path length**: 933 nodes
- **STA (core_clock)**: Required 99.8755 ns, Actual 122.3277 ns, Slack **-22.4522 ns (VIOLATED)**

## Trojan 2 — MAC Address Filter Bypass

Sources:
- `Trojan_2/metrics/ppa/area_report.txt`
- `Trojan_2/metrics/ppa/sta_report.txt`
- `Trojan_2/metrics/ppa/timing_report.txt`

Extracted:
- **Cells**: 23,289
- **Chip area**: 416,525.7312 µm²
- **Sequential area**: 309,708.2848 µm² (74.36%)
- **Longest topological path length**: 933 nodes
- **STA (core_clock)**: Required 99.8755 ns, Actual 122.3277 ns, Slack **-22.4522 ns (VIOLATED)**

## Trojan 3 — PAUSE Frame DoS

Sources:
- `Trojan_3/metrics/ppa/area_report.txt`
- `Trojan_3/metrics/ppa/sta_report.txt`
- `Trojan_3/metrics/ppa/timing_report.txt`

Extracted:
- **Cells**: 23,289
- **Chip area**: 416,525.7312 µm²
- **Sequential area**: 309,708.2848 µm² (74.36%)
- **Longest topological path length**: 933 nodes
- **STA (core_clock)**: Required 99.8755 ns, Actual 122.3277 ns, Slack **-22.4522 ns (VIOLATED)**

