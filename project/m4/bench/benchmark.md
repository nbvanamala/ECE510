# Benchmark Report — M4 Final
## Edge CNN Accelerator | ECE510 Spring 2026 | Naveen Babu Vanamala

All numbers in this document are directly traceable to `benchmark_data.csv`.
The simulation log `project/m4/sim/final_run.log` contains the raw timing output.

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

**Measurement method:** Cycle-accurate co-simulation via Icarus Verilog 12.0
(WSL), `project/m4/tb/tb_top.sv`. The testbench loads 4 weights once (one-time
cost), then runs **3 back-to-back patch invocations** with `$time` markers at
start and end. Every number below is printed directly in `final_run.log`.

**Raw timing from log (directly traceable):**

| Measurement          | Value from log                              |
|----------------------|---------------------------------------------|
| Measurement start    | t = 375 ns (after weight load)              |
| Measurement end      | t = 4,906 ns (after 3rd result readback)    |
| Elapsed (3 patches)  | 4,531 ns                                    |
| Total cycles (3 patches) | 453 cycles (4531 ns ÷ 10 ns/cycle)     |
| **Cycles per patch** | **151 cycles** (453 ÷ 3)                   |
| Time per patch       | 1,510 ns (151 × 10 ns)                      |

**Derived throughput (from 151 cycles/patch, 100 MHz):**

- Time per image  = 900 patches × 1,510 ns = **1.359 ms**
- Throughput      = 64,800 FLOPs ÷ 1.359 ms = **47.7 MFLOPs/s**
- Samples/sec     = 1 ÷ 1.359 ms = **736 images/sec**

All values labeled **(measured, cosim)**.

---

## Speedup vs M1 Software Baseline

**M1 software baseline** (from `project/m1/sw_baseline.md`):
Python im2col nested loop, INT8 arithmetic, measured on Windows 11
i7-compatible host, Python 3.13, NumPy 2.4.4.

| Metric                 | SW Baseline (M1 loop) | HW Accelerator (M4, measured cosim) |
|------------------------|-----------------------|--------------------------------------|
| Time per image         | 10.966 ms             | **1.359 ms**                         |
| Time per patch         | 12.18 µs              | **1.510 µs** (151 cycles × 10 ns)    |
| Throughput (MFLOPs/s)  | 5.91                  | **47.7**                             |
| Samples/sec            | 91.2 img/s            | **736 img/s**                        |
| Clock                  | i7-1165G7, ~3.1 GHz   | sky130A sim, 100 MHz                 |
| Energy/image (est.)    | ~307 mJ (28 W TDP)    | **~3.14 µJ** (2.31 mW × 1.359 ms)   |

**Speedup = SW_time / HW_time = 10.966 ms / 1.359 ms = 8.07×**

---

## AXI-Overhead Cycle Breakdown

The 151-cycle per-patch figure is dominated by AXI4-Lite bus transactions:

| Phase                    | Cycles (measured from log timestamps) | Fraction |
|--------------------------|---------------------------------------|----------|
| 9 pixel taps (PIXEL_IN + CTRL each, ~14 cy/tap) | 126 cycles | 83.4% |
| DONE poll (1 AXI read)   | 5 cycles                              |  3.3%   |
| 4 result reads (5 cy ea) | 20 cycles                             | 13.2%   |
| **AXI total overhead**   | **142 cycles**                        | **94.0%**|
| MAC compute (9 taps × 1 cycle) | 9 cycles                       |  6.0%   |
| **Total**                | **151 cycles**                        | 100%     |

**MAC utilization: 9 ÷ 151 = 5.96%**. The design is AXI-overhead-bound: 142 of
151 cycles are bus transactions. The path to higher throughput is a streaming
pixel FIFO (see report Section 9) that would reduce this to ~30 cycles/patch.

---

## Energy Comparison

| Metric                | SW Baseline                  | HW Accelerator (M4)            |
|-----------------------|------------------------------|--------------------------------|
| Power                 | ~28 W (i7-1165G7 TDP)        | **2.31 mW** (OpenROAD sky130A) |
| Energy/image          | ~307 mJ (28 W × 10.966 ms)  | **~3.14 µJ** (2.31 mW × 1.359 ms) |
| Energy reduction      | 1× (baseline)                | **~97,800×**                   |
| Efficiency (MFLOPs/W) | 0.211                        | **20.6** (47.7 MFLOPs/s ÷ 2.31 mW)|

---

## Roofline Position

The M4 measured accelerator point:
- **Arithmetic intensity**: 2.48 FLOPs/byte
- **Throughput**: 47.7 MFLOPs/s = 0.0477 GFLOPs/s

Sky130A bandwidth ceiling at AI=2.48: ~330 MFLOPs/s (from CF09 analysis).
The measured design is **6.9× below the bandwidth ceiling**, operating deep in
the AXI-overhead-bound regime. See `roofline_final.png` for the plot.

Raw measurement data: `benchmark_data.csv`
