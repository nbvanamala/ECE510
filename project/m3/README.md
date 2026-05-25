# Milestone 3 — Edge CNN Accelerator Using a Weight-Stationary Systolic Array
## ECE510 Spring 2026 | Naveen Babu Vanamala

## File Catalog
- `README.md` — this file; catalogs all M3 files and subfolders
- `rtl/top.sv` — integrated top module connecting M2 interface and compute core; glue logic includes weight_wr pipeline, valid_in delay, result capture registers (0x10-0x1C), and sticky DONE flag (0x20) readable via AXI4-Lite
- `tb/tb_top.sv` — end-to-end co-simulation testbench; drives AXI4-Lite write channel for weights and 9 pixel taps (pixels 1-9), polls DONE flag (0x20) via AXI read, reads PE results at 0x10-0x1C; no direct compute-core port access
- `sim/cosim_run.log` — simulation transcript (Icarus Verilog 12.0), ends with PASS; PE0=135, PE1=315, PE2=-90, PE3=225
- `sim/cosim_waveform.png` — waveform showing three regions: (1) AXI weight writes, (2) pixel tap streaming, (3) AXI DONE poll and result reads
- `sim/cosim_waveform.vcd` — raw VCD waveform dump from simulation
- `synth/config.json` — OpenLane 2 configuration (clock 10 ns, sky130A PDK, design top)
- `synth/synth.ys` — Yosys 0.33 synthesis script
- `synth/openlane_run.log` — Yosys 0.33 synthesis run; 4305 cells, 0 errors, 0 latches
- `synth/area_report.txt` — cell count from Yosys run; 4305 total cells, module breakdown
- `synth/timing_report.txt` — critical path from Yosys netlist; pixel_out to accum_reg estimated 2.75 ns
- `synth/power_report.txt` — power estimate at 100 MHz; 0.57 mW; full OpenLane power flow deferred to M4
- `synth/critical_path.md` — critical path: pixel_out register to 8x8 multiplier to 32b ripple adder to accum_reg
- `synthesis_notes.md` — narrative 500+ words: what synthesized, glue logic issues, timing, scope status

## How to Run Co-Simulation
**Simulator:** Icarus Verilog 12.0

```bash
cd project/m3/sim
iverilog -g2012 -o tb_top \
  ../tb/tb_top.sv \
  ../rtl/top.sv \
  ../../m2/rtl/conv_pe.sv \
  ../../m2/rtl/compute_core.sv \
  ../../m2/rtl/interface.sv
vvp tb_top | tee cosim_run.log
```
Expected: ends with PASS

## How to Run Yosys Synthesis
**Tool:** Yosys 0.33

```bash
cd project/m3/synth
yosys synth.ys 2>&1 | tee openlane_run.log
```
**Config file:** project/m3/synth/config.json
**PDK:** sky130A — must be installed at $PDK_ROOT/sky130A for full OpenLane run
