# Benchmark Results — CF09 Task 8
## ECE510 Spring 2026 | Naveen Babu Vanamala
## Edge CNN Accelerator — SW Baseline vs. HW Accelerator

---

### Kernel Configuration (common to both rows)

| Parameter         | Value                                          |
|-------------------|------------------------------------------------|
| Kernel type       | 3×3 INT8 Conv2D (weight-stationary)            |
| Kernel size       | 9 taps (KERNEL\_SIZE = 9)                       |
| Output channels   | 4 (matches NUM\_PE = 4)                         |
| Input channels    | 1 (single-channel broadcast)                   |
| Input spatial     | 32×32 pixels → 900 output patches              |
| FLOPs per patch   | 72 (9 MACs × 4 PEs × 2 FLOPs/MAC)             |
| FLOPs per image   | 64,800 (900 patches × 72 FLOPs)                |
| Arithmetic intensity | 2.48 FLOPs/byte (lower, no reuse)           |

---

### Task 6 — SW Baseline Re-run

Re-run method: Python loop im2col (nested loops over output positions, INT8
inputs, int32 accumulation), matching the M1 `cnn_backprop` style described
in `project/m1/sw_baseline.md`. Measured on same hardware (Windows 11,
i7-compatible host, Python 3.13.13, NumPy 2.4.4).

### Task 7 — HW Accelerator (Measured Path)

Measurement source: M3 co-simulation (`project/m3/sim/cosim_run.log`),
Icarus Verilog at 100 MHz (10 ns period). All 3 test invocations PASS.
Simulation ends at **t = 3,596 ns = 360 clock cycles** for 3 complete
test-reset-execute-readback cycles.

Per-patch timing: 360 cycles / 3 invocations = **120 cycles per invocation**
(includes FSM reset, 4-weight AXI load, 9-pixel AXI stream, result readback).
At 100 MHz: **1,200 ns per patch invocation**.

For one 32×32 image (900 patches back-to-back with reset):
- Time = 900 × 1,200 ns = **1.08 ms**
- Throughput = 64,800 FLOPs / 1.08 ms = **60.0 MFLOPs/s**

All HW numbers are labeled **measured (cosim)**.

---

### Task 8 — Comparison Table

| Metric                  | SW Baseline (M1 loop) | HW Accelerator (measured, cosim) |
|-------------------------|-----------------------|----------------------------------|
| Implementation          | Python im2col loop    | `cnn_top` M3, 100 MHz, sky130A   |
| Exec time per image     | 10.966 ms             | **1.08 ms** (projected from patch) |
| Exec time per patch     | 0.0122 ms (12.2 μs)   | **1.200 μs** (120 cycles)        |
| Throughput (MFLOPs/s)   | 5.91                  | **60.0**                         |
| Samples/sec (img/s)     | 91.2                  | **926**                          |
| Memory usage            | 15.6 KB               | on-chip only (4 × INT8 weights + ACC) |
| Energy (est.)           | ~28 W (i7 TDP)        | ~0.5–2 mW (est. sky130A ~0.05 mm²) |
| Speedup (vs SW loop)    | 1× (baseline)         | **10.15×**                       |

**Speedup formula:** SW_time / HW_time = 10.966 ms / 1.08 ms = **10.15×**

> Note: The NumPy vectorized implementation (GEMM) achieves 1,527 MFLOPs/s
> (25.5× faster than SW loop, 25× faster than the HW accelerator) because
> NumPy batches all 900 patches into a single BLAS GEMM call, hiding
> per-patch overhead. The hardware currently processes patches sequentially
> through AXI4-Lite with 120 cycles/patch overhead; only 9 of those cycles
> are actual MAC compute (7.5% utilization). This is the primary gap to
> address before M4.

---

### Energy Efficiency Note

Energy data from synthesis is not available (Yosys generic gate library;
power estimation requires OpenLane 2 full flow with sky130A PDK). Estimated
power from sky130A typical figures (~0.15 µW/MHz/gate, 2,316 sky130 cells,
100 MHz): **~35 mW static + dynamic ≈ 50–100 mW total**. At 60 MFLOPs/s:
estimated efficiency ≈ **0.6–1.2 GFLOPs/W**, versus i7-1165G7 at 28 W TDP
achieving 5.91 MFLOPs/s → **0.00021 GFLOPs/W**.
Estimated energy efficiency improvement: **≈ 3,000–5,000×** (order of magnitude).
