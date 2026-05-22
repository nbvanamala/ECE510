# Project Scope Assessment
## ECE510 Spring 2026 | Naveen Babu Vanamala | Updated: CF07

## Current Scope (confirmed)

**Project:** Edge CNN Accelerator — weight-stationary systolic array
for INT8 Conv2D im2col on sky130A.

**Core module:** compute_core.sv — 4x conv_pe PEs in parallel, each
accumulating 9 INT8 MACs per output channel.

**Interface:** AXI4-Lite slave for CPU to accelerator control.

## CF07 OpenLane 2 Synthesis Result

| Metric | Value |
|--------|-------|
| Total standard cells | 7,274 |
| Cell area | 53,346 µm² |
| Die area | 115,435 µm² |
| Core utilization | 51.4% |
| Flip-flops | 434 |
| WNS nominal corner | +2.32 ns |
| WNS nom_ss corner (nom_ss_100C_1v60) | -3.01 ns |
| WNS overall worst (max_ss_100C_1v60) | -3.17 ns |
| Setup violations (ss) | 170 endpoints |
| DRC | Passed |
| LVS | Passed |

## Scope Adjustments for M3

1. **Add SDC file** — fix generic fallback timing constraint issue.
2. **Pipeline critical path** — address -3.01 ns nom_ss violation (worst -3.17 ns at max_ss).
3. **Keep 100 MHz clock target** — nominal corner closes cleanly.
4. **Keep INT8 precision** — 53,346 µm² is within sky130A capacity.
5. **Interface unchanged** — AXI4-Lite remains as planned.

Scope is confirmed and feasible based on OpenLane 2 results.
