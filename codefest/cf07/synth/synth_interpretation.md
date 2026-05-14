# Synthesis Interpretation — compute_core
## ECE510 CF07 | Naveen Babu Vanamala

**Tool:** OpenLane 2 (Classic flow), sky130A PDK, sky130_fd_sc_hd standard cell library.

---

### (a) Clock Period and Worst-Case Slack

Clock target: **10 ns (100 MHz)**. In the nominal corner (nom_tt_025C_1v80),
worst-case setup slack (WNS) is **+2.32 ns** — timing closes cleanly. However,
in the slow-slow corner (nom_ss_100C_1v60), WNS is **-3.17 ns** with 170
violating endpoints and TNS of -271 ns. The design passes timing at typical
conditions but fails at slow process and low voltage.

### (b) Critical Path

Source register: accumulator DFF inside pe_array instances (accum_reg,
type sky130_fd_sc_hd__dfxtp). Sink register: result_data output register
in compute_core. Dominant cell types: multi-input combinational cells
(4,383 instances) implementing the 8-bit multiplier partial-product tree
and 32-bit carry-propagate accumulator chain. All four PEs share identical
structure giving symmetric worst-case paths.

### (c) Total Cell Area and Top Contributors

Total standard cell area: **53,346 µm²** across **7,274 cells**.
Die area: 115,435 µm². Core utilization: 51.4%.
Top three contributors by instance count:
1. Multi-input combinational cells — 4,383 (60.3%) — multiplier and adder logic
2. Sequential cells — 434 (6.0%) — accumulator and pipeline registers
3. Fill/tap cells — 8,534 — physical-only, no logic function

### (d) Violations and Warnings

Setup violations in all three slow-slow corners (ss_100C_1v60): WNS ranges
from -2.85 ns to -3.17 ns with 168-172 failing endpoints. Antenna violations:
3 pin violations and 3 net violations. No hold violations in any corner.
Key warning: no SDC file provided — OpenLane used generic fallback constraints.
DRC passed. LVS passed.
