# Milestone 2 — Edge CNN Accelerator
## ECE510 Spring 2026 | Naveen Babu Vanamala

## Overview
RTL for Edge CNN Accelerator targeting Conv2D._im2col (80.6% of runtime).
INT8 systolic array raises arithmetic intensity from 2.48 to ~10 FLOP/byte.

## Files
| File | Purpose |
|------|---------|
| rtl/conv_pe.sv | INT8 PE submodule — 9-tap MAC |
| rtl/compute_core.sv | Top-level: 4 PEs, weight SRAM, pixel broadcast |
| rtl/interface.sv | Top-level: AXI4-Lite slave, 4-register map |
| tb/tb_compute_core.sv | 4 tests: reset, all-ones, 9x3x7=189, negative |
| tb/tb_interface.sv | 5 tests: reset, write/read pixel/weight/ctrl/status |
| sim/compute_core_run.log | PASS |
| sim/interface_run.log | PASS |
| sim/waveform.png | GTKWave waveform |
| precision.md | INT8 error analysis |
| README.md | This file |

## Deviation from M1
interface is a reserved SystemVerilog keyword. Module in interface.sv
is named axi4lite_slave wrapped by cnn_interface. File named interface.sv
as required by checklist. No other deviations.

## How to Run

### Install
    sudo apt install iverilog gtkwave -y

### Compute Core
    cd project/m2/sim
    iverilog -g2012 -o tb_cc ../rtl/conv_pe.sv ../rtl/compute_core.sv ../tb/tb_compute_core.sv
    vvp tb_cc | tee compute_core_run.log

### Interface
    iverilog -g2012 -o tb_if ../rtl/interface.sv ../tb/tb_interface.sv
    vvp tb_if | tee interface_run.log

### Waveform
    gtkwave compute_core.vcd &
