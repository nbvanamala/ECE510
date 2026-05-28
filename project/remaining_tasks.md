# Remaining Tasks Before M4
## ECE510 Spring 2026 | Naveen Babu Vanamala | Updated: CF09

---

### Task 1 — Replace AXI4-Lite per-patch write loop with a streaming pixel FIFO

**Current bottleneck:** Each patch invocation requires 13 AXI transactions
(4 weight writes + 9 pixel writes) totalling ~111 bus cycles before any MAC
compute begins, limiting throughput to 60 MFLOPs/s (7.5% MAC utilization).

**Specific change:** Add a 9-deep pixel FIFO on the AXI write path so the
host streams all 9 pixels in a burst (`PIXEL_IN` register auto-queues), then
fires a single `START` strobe rather than 9 separate CTRL writes. This reduces
the pixel-stream overhead from 54 AXI cycles to 9 FIFO-write cycles plus 1
strobe cycle, collapsing per-patch latency from ~120 cycles to ~30 cycles and
raising throughput to ~240 MFLOPs/s (within 1.4× of the BW ceiling).

**Files to modify:** `project/m3/rtl/interface.sv` (add FIFO state and
auto-valid generation), `project/m3/rtl/top.sv` (remove pixel-count FSM
state, transition on FIFO non-empty).

---

### Task 2 — Expand NUM\_PE from 4 to 8 and widen `weight_addr` to `[2:0]`

**Current limitation:** `compute_core.sv` has `weight_addr` hard-coded as
`[1:0]` (lines 27 and 48 of `project/m2/rtl/compute_core.sv`). Expanding to
8 PEs doubles throughput per clock cycle (144 FLOPs/patch) but requires
widening this port to `[2:0]` to avoid silent truncation (the CF07
interpretation report explicitly flags this). The M3 plan (CF07 `m3_plan.md`)
calls for NUM\_PE = 8 at 250 MHz, targeting ~2.9 GFLOPs/s.

**Specific change:** Update `parameter NUM_PE = 4` → `8` in
`compute_core.sv` line 36, change `weight_addr` port to `[2:0]` in
`compute_core.sv` line 45 and `top.sv` line 89 (`w_load_cnt [2:0]` and
`weight_addr_lat [2:0]`), rerun synthesis, update `m3_plan.md` with new
cell-count and timing estimates.

---

### Task 3 — Run full OpenLane 2 flow on sky130A to obtain real area, power, and STA numbers

**Current gap:** All timing and area figures are either Yosys generic-gate
estimates (CF07) or Yosys-mapped-to-sky130 without place-and-route (M3).
No real WNS, TNS, or power report exists. M4 requires measured metrics.

**Specific change:** Execute `run_openlane.sh` from `project/m3/synth/`
inside a Docker container with the `efabless/openlane2` image. The config
(`project/m3/synth/config.json`) already targets sky130A HD and sets
`CLOCK_PERIOD = 10.0`. Capture `final/reports/metrics.csv` (area in µm²,
WNS, TNS, cell count), `final/reports/power.rpt`, and replace the analytical
timing estimates in `project/scope_assessment.md` with real STA numbers.
If WNS is negative at 100 MHz, relax to 150 MHz (estimated slack allows it)
and document the change.
