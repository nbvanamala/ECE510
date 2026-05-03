# Milestone 2 — Edge CNN Accelerator for Industrial AI Applications
## ECE510 Spring 2026 | Naveen Babu Vanamala

---

## What This Project Does

This accelerator targets the `Conv2D._im2col` convolution kernel which was
identified in M1 profiling as the dominant bottleneck — 80.6% of total
runtime (31.2 out of 38.7 seconds) on a CPU.

The hardware replaces Python/NumPy nested loops with parallel INT8 MAC units
that reuse stationary weights from on-chip SRAM. This raises arithmetic
intensity from 2.48 FLOP/byte to ~10 FLOP/byte, moving the kernel from
memory-bound into the compute-bound regime (as shown in the M1 roofline).

Real-world application: factory cameras doing defect detection on an embedded
edge device — no cloud, no GPU, low power.

---

## All Files Submitted — What Each One Does

### RTL (project/m2/rtl/)

| File | Module Name | What it does |
|------|-------------|--------------|
| `rtl/conv_pe.sv` | `conv_pe` | Single INT8 processing element. Takes one pixel and one weight per clock cycle. Accumulates 9 signed 8-bit multiply-accumulate (MAC) operations into a 32-bit result. Pulses `valid_out` for one cycle when the 9th tap is done. This is the building block — one PE per output channel. |
| `rtl/compute_core.sv` | `compute_core` | **Top-level compute core (required filename).** Instantiates 4 `conv_pe` units in parallel. Each PE holds its own stationary weight stored in on-chip weight memory. The same pixel is broadcast to all 4 PEs every cycle. All 4 results are packed into a 128-bit output bus. This is the systolic array core. |
| `rtl/interface.sv` | `axi4lite_slave` wrapped by `cnn_interface` | **Top-level interface module (required filename).** AXI4-Lite slave — the protocol selected in M1. The host CPU writes pixel and weight values over AXI4-Lite, and triggers computation via the CTRL register. See register map below. |

### Testbenches (project/m2/tb/)

| File | What it does |
|------|--------------|
| `tb/tb_compute_core.sv` | Testbench for `compute_core`. Drives 4 independent test vectors: (1) reset check, (2) all-ones 9×1×1=9, (3) representative 9×3×7=189 — mirrors the im2col patch values from M1 profiling, (4) negative weight 9×5×(−3)=−135. Reference values computed independently in Python. Prints PASS or FAIL. |
| `tb/tb_interface.sv` | Testbench for `cnn_interface`. Drives 5 test cases: (1) reset check, (2) write pixel register 0x42 and read back, (3) write weight register 0x07 and read back, (4) write CTRL=1 and read back — confirms start pulse, (5) assert done_in and read STATUS register. Prints PASS or FAIL. |

### Simulation Artifacts (project/m2/sim/)

| File | What it contains |
|------|-----------------|
| `sim/compute_core_run.log` | Full simulation transcript from running `vvp tb_cc` on Ubuntu with Icarus Verilog 12.0. All 4 tests PASS. Last line: `PASS`. |
| `sim/interface_run.log` | Full simulation transcript from running `vvp tb_if` on Ubuntu with Icarus Verilog 12.0. All 5 tests PASS. Last line: `RESULT: PASS`. |
| `sim/waveform.png` | Waveform showing clk, rst, valid_in, pixel_in, result_valid, and pe0_result signals. Shows the full pipeline: reset → weight load → 9 pixel taps → result valid → output = 189. |

### Documentation (project/m2/)

| File | What it contains |
|------|-----------------|
| `precision.md` | INT8 format choice with rationale tied to the M1 roofline. Explains why INT8 and not INT4 or FP16. Includes 100-sample quantization error analysis (MAE=0.0031, max error=0.0089). Acceptability statement. 813 words. |
| `README.md` | This file. Lists all submitted files, explains deviations from the M2 checklist. |

---

## AXI4-Lite Register Map (interface.sv)

| Address | Register | Direction | What it does |
|---------|----------|-----------|--------------|
| 0x00 | PIXEL_IN | Write/Read | Signed INT8 pixel value sent to compute core |
| 0x04 | WEIGHT_IN | Write/Read | Signed INT8 weight value sent to compute core |
| 0x08 | CTRL | Write/Read | Write 1 to trigger start pulse (valid_out). Self-clearing. |
| 0x0C | STATUS | Read only | Reads 1 when done_in is asserted by accelerator |

---

## Deviations from M2 Checklist — Explained

### 1. interface.sv module name

The M2 checklist requires a file named `interface.sv`.
However, `interface` is a **reserved keyword in SystemVerilog** and cannot
be used as a module name. Icarus Verilog 12.0 returns a syntax error if you
try `module interface`.

**What was done:** The file is named `interface.sv` exactly as required.
Inside the file, the top-level module is named `cnn_interface`, which
instantiates `axi4lite_slave`. The wrapper `cnn_interface` has identical
ports to what the checklist describes. The testbench `tb_interface.sv`
instantiates `cnn_interface`.

### 2. conv_pe.sv as a submodule

The professor confirmed that submodules in separate files are acceptable
as long as `compute_core.sv` exists as the named top-level file.
`conv_pe.sv` is placed in `rtl/` alongside `compute_core.sv` and is
compiled together in the iverilog command.

### 3. No changes from M1

- Kernel scope: Conv2D im2col — unchanged
- Interface protocol: AXI4-Lite — unchanged
- Numerical precision: INT8 — unchanged

---

## How to Reproduce — Exact Commands

### Install (Ubuntu)
```bash
sudo apt install iverilog -y
iverilog -V   # must show: Icarus Verilog version 12.0
```

### Run Compute Core Simulation
```bash
cd project/m2/sim

iverilog -g2012 -o tb_cc \
  ../rtl/conv_pe.sv \
  ../rtl/compute_core.sv \
  ../tb/tb_compute_core.sv

vvp tb_cc | tee compute_core_run.log
```
Last line of output: `PASS`

### Run Interface Simulation
```bash
cd project/m2/sim

iverilog -g2012 -o tb_if \
  ../rtl/interface.sv \
  ../tb/tb_interface.sv

vvp tb_if | tee interface_run.log
```
Last line of output: `RESULT: PASS`

### View Waveform
```bash
gtkwave project/m2/sim/compute_core.vcd
```

---

## M1 Files Still Present

All M1 files remain at their original paths as required:
- `project/m1/interface_selection.md`
- `project/m1/sw_baseline.md`
- `project/m1/system_diagram.png`
