# Project Scope Assessment
## ECE510 Spring 2026 | Naveen Babu Vanamala | Updated: CF07

---

## Current Scope (confirmed)

**Project:** Edge CNN Accelerator — weight-stationary systolic array for
INT8 Conv2D im2col on sky130A.

**Core module:** `compute_core.sv` — 4× `conv_pe` PEs in parallel, each
accumulating 9 INT8 MACs per output channel.

**Interface:** AXI4-Lite slave (`cnn_interface`) for CPU ↔ accelerator
control and data transfer.

---

## CF07 Synthesis Result

Yosys 0.65 synthesis of `compute_core` (4 PEs, KERNEL\_SIZE=9, INT8):

| Metric | Value |
|--------|-------|
| Total cells | 4,039 |
| Flip-flops | 434 |
| Estimated critical path | 2.84 ns |
| Estimated WNS at 100 MHz | +7.16 ns |
| Synthesis warnings | 0 |

**Conclusion:** The design is well within sky130A's capabilities. The cell
count is small (estimated <0.05 mm² in sky130A HD), the critical path has
large positive slack at the 100 MHz target, and no timing closure issues
are anticipated.

---

## Scope Adjustments for M3

1. **Clock target raised to 250 MHz** — justified by +7.16 ns slack headroom.
2. **PE count expanded to 8** — linear area scaling remains feasible (~8,000
   cells estimated).
3. **Full OpenLane 2 run** — M3 will include real sky130A place-and-route
   and STA (Docker environment required).
4. **No precision change** — INT8 confirmed correct by M2 quantization analysis
   (MAE = 0.0031, max error = 0.0089); no need to drop to INT4.
5. **Interface scope unchanged** — AXI4-Lite remains; no new protocol needed.

The project scope is **confirmed and feasible** based on synthesis evidence.
No descoping is needed.
