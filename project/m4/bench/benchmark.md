# Benchmark Report — M4 Final
## Edge CNN Accelerator | ECE510 Spring 2026 | Naveen Babu Vanamala

---

## Kernel Configuration

| Parameter            | Value                                             |
|----------------------|---------------------------------------------------|
| Kernel type          | 3×3 INT8 Conv2D (weight-stationary)               |
| Kernel size          | 9 taps (KERNEL_SIZE = 9)                          |
| Output channels      | 4 (NUM_PE = 4 processing elements)                |
| Input channels       | 1 (single-channel broadcast)                      |
| Input spatial        | 32×32 pixels → 900 output patches                 |
| FLOPs per patch      | 72 (9 MACs × 4 PEs × 2 FLOPs/MAC)                |
| FLOPs per image      | 64,800 (900 patches × 72 FLOPs)                   |
| Arithmetic intensity | 2.48 FLOPs/byte (lower bound, no weight reuse)    |

---

## Measured Accelerator Throughput

**Measurement method:** Cycle-count from co-simulation (Icarus Verilog 12.0,
100 MHz clock, 10 ns period). The testbench (`project/m4/tb/tb_top.sv`) drives
the AXI4-Lite interface, writes 4 weights and 9 pixel taps, fires CTRL strobe,
and polls DONE. Three complete reset-execute-readback cycles were measured.

**Raw measurement:** Simulation ends at t = 3,596 ns = 360 clock cycles for
3 invocations. Per-patch: 360 / 3 = **120 cycles/patch** (includes FSM reset,
4× AXI weight write, 9× AXI pixel write + CTRL strobe, DONE readback).

At 100 MHz (10 ns/cycle):
- Time per patch  = 120 × 10 ns = **1,200 ns = 1.20 µs**
- Time per image  = 900 patches × 1.20 µs = **1.08 ms**
- Throughput      = 64,800 FLOPs / 1.08 ms = **60.0 MFLOPs/s**
- Samples/sec     = 1 / 1.08 ms = **926 images/sec**

All values labeled **(measured, cosim)**.

---

## Speedup vs M1 Software Baseline

**M1 software baseline** (from `project/m1/sw_baseline.md`):
Python im2col nested loop, INT8 arithmetic, measured on Windows 11 i7-compatible
host, Python 3.13, NumPy 2.4.4.

| Metric                 | SW Baseline (M1 loop) | HW Accelerator (M4 cosim)        |
|------------------------|-----------------------|----------------------------------|
| Time per image         | 10.966 ms             | **1.08 ms**                      |
| Time per patch         | 12.2 µs               | **1.20 µs**                      |
| Throughput (MFLOPs/s)  | 5.91                  | **60.0**                         |
| Samples/sec            | 91.2 img/s            | **926 img/s**                    |
| Clock                  | i7-1165G7, ~3.1 GHz   | sky130A simulation, 100 MHz      |
| Energy/image (est.)    | ~0.307 J (28 W TDP)   | **~2.49 µJ** (2.31 mW × 1.08 ms)|

**Speedup = SW_time / HW_time = 10.966 ms / 1.08 ms = 10.15×**

The hardware accelerator achieves **10.15× speedup** over the Python loop baseline.

---

## Performance Gap Analysis

The 10.15× speedup is far below the theoretical peak. Root cause analysis:

| Overhead category     | Cycles (per patch) | Fraction |
|-----------------------|--------------------|----------|
| AXI weight writes     | 4 × ~14 cycles     | ~56 cy   | 46.7%
| AXI pixel + CTRL      | 9 × ~6 cycles      | ~54 cy   | 45.0%
| Actual MAC compute    | 9 cycles           |          |  7.5%
| FSM reset overhead    | ~1 cycle           |          |  0.8%
| **Total**             | **120 cycles**     |          | 100%

**MAC utilization: 9/120 = 7.5%**. The design is AXI-protocol-overhead-bound:
111 of 120 cycles are bus transactions, not computation. The sky130A roofline
bandwidth ceiling (computed in CF09) is 360 MFLOPs/s for this arithmetic
intensity; the measured 60 MFLOPs/s is 6.0× below that ceiling.

A streaming pixel FIFO (described in `project/remaining_tasks.md` Task 1)
would collapse per-patch bus overhead from 120 cycles to ~30 cycles, raising
throughput to ~240 MFLOPs/s (4× improvement within reach of BW ceiling).

---

## Energy Comparison

| Metric                | SW Baseline                | HW Accelerator               |
|-----------------------|----------------------------|------------------------------|
| Power                 | ~28 W (i7-1165G7 TDP)      | **2.31 mW** (OpenROAD, sky130A) |
| Energy/image          | ~0.307 J (28 W × 10.97 ms) | **~2.49 µJ** (2.31 mW × 1.08 ms)|
| Energy reduction      | 1× (baseline)              | **~123,000×**                |
| Efficiency (GFLOPs/W) | 0.00021                    | **0.026** (60 MFLOPs/s ÷ 2.31 mW)|

Note: SW energy uses i7 TDP (conservative upper bound). HW power is from
OpenROAD pre-route estimate; actual post-route power may differ by ±20%.

---

## Roofline Position

The M4 measured accelerator point plots at:
- **Arithmetic intensity**: 2.48 FLOPs/byte
- **Throughput**: 60.0 MFLOPs/s = 0.060 GFLOPs/s

The sky130A sky130_fd_sc_hd roofline ridge point is at ~6.0 FLOPs/byte
(bandwidth ceiling = 360 MFLOPs/s at 2.48 AI). The measured design operates
at **16.7% of the bandwidth ceiling** — deep in the memory/interface-bound
regime. See `roofline_final.png` for the plot.

Raw measurement data: `benchmark_data.csv`
