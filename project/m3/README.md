# Milestone 3 - Edge CNN Accelerator Integration
## ECE510 Spring 2026 - Naveen Babu Vanamala

## File Catalog
- `README.md` — this file; catalogs all M3 files and subfolders
- `rtl/top.sv` — integrated top module connecting M2 interface and compute core; glue logic includes weight_wr pipeline, valid_in delay, result capture registers (0x10-0x1C), and sticky DONE flag (0x20) readable via AXI4-Lite
- `tb/tb_top.sv` — end-to-end co-simulation testbench; drives AXI4-Lite write channel for weights and 9 distinct pixel taps (pixels 1-9), polls DONE flag (0x20) via AXI read, reads PE results via AXI at 0x10-0x1C; no direct compute-core port access
- `sim/cosim_run.log` — simulation transcript (Icarus Verilog 12.0), ends with PASS; PE0=135, PE1=315, PE2=-90, PE3=225
- `sim/cosim_waveform.png` — waveform image showing three regions: (1) AXI weight writes, (2) pixel tap streaming, (3) AXI DONE poll and result reads
- `sim/cosim_waveform.vcd` — raw VCD waveform dump from simulation
- `synth/config.json` — OpenLane 2.3.10 configuration (clock 10 ns, sky130A PDK, design top)
- `synth/synth.ys` — Yosys synthesis script used for M3 synthesis run
- `synth/openlane_run.log` — Yosys 0.33 actual synthesis run on integrated top; 6013 generic cells, 781 FFs, 0 errors, 0 problems
- `synth/area_report.txt` — cell count from actual Yosys run on integrated top; 6013 cells, module breakdown
- `synth/timing_report.txt` — structural critical path from Yosys netlist; pixel_out to accum_reg estimated 2.75 ns; full PnR STA deferred to M4
- `synth/power_report.txt` — real OpenROAD report_power from OpenLane 2.3.10; compute core 6.26 mW at nom_tt 100 MHz
- `synth/critical_path.md` — critical path analysis; pixel_out register to 8x8 multiplier to 32b ripple adder to accum_reg
- `synthesis_notes.md` — narrative 500+ words: what synthesized, timing/power numbers, glue logic issues, M4 plan

## How to Run Co-Simulation
Simulator: Icarus Verilog 12.0

```bash
