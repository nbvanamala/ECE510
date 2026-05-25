# Milestone 3 — Edge CNN Accelerator Using a Weight-Stationary Systolic Array
## ECE510 Spring 2026 | Naveen Babu Vanamala

## File Catalog
- `README.md` — this file; catalogs all M3 files and subfolders
- `rtl/top.sv` — integrated top module connecting M2 cnn_interface and compute_core; glue logic includes weight_wr two-stage pipeline (weight_wr_raw→weight_wr_r) for weight_out settling, valid_in_delayed one-cycle delay for pixel_out settling, result capture registers at 0x10–0x1C, and sticky DONE flag at 0x20 readable via AXI4-Lite read
- `tb/tb_top.sv` — end-to-end co-simulation testbench; drives AXI4-Lite write channel for 4 PE weights (addr 0x04) and 9 distinct pixel taps (addr 0x00 + CTRL 0x08), polls sticky DONE flag at 0x20 via AXI read, reads PE results at 0x10–0x1C; no direct compute-core port access
- `sim/cosim_run.log` — simulation transcript (Icarus Verilog 12.0); ends with PASS; PE0=135, PE1=315, PE2=−90, PE3=225
- `sim/cosim_waveform.png` — annotated waveform with three labeled regions: (1) AXI weight writes, (2) pixel tap streaming with valid_in, (3) AXI DONE poll and result reads
- `sim/cosim_waveform.vcd` — raw VCD dump from Icarus Verilog simulation
- `synth/config.json` — OpenLane 2 configuration (design=top, clock=10 ns, PDK=sky130A, source list)
- `synth/synth.ys` — Yosys 0.33 standalone synthesis script (read_verilog → hierarchy → proc → opt → fsm → memory → techmap → stat)
- `synth/run_synth.ys` — synthesis script actually run to produce openlane_run.log
- `synth/openlane_run.log` — **actual Yosys 0.33 stdout** from running `yosys run_synth.ys`; 4305 cells, 0 errors, 0 latches; this is the real tool output
- `synth/area_report.txt` — cell count from actual Yosys stat output; 4305 total cells with per-module and per-type breakdown
- `synth/timing_report.txt` — structural critical path from Yosys netlist; start=pixel_out FF, end=accum_reg; estimated 2.75 ns total, WNS +7.25 ns at 100 MHz
- `synth/power_report.txt` — power estimate derived from actual synthesized cell counts (778 FFs, 3527 logic cells); ~0.60 mW at 100 MHz; full OpenLane report_power deferred to M4
- `synth/critical_path.md` — critical path analysis: pixel_out → 8×8 multiplier → 32b adder → accum_reg; explanation of why this path dominates and three options to shorten it
- `synth/work/` — intermediate Yosys working files (synthesized netlist, scripts)
- `synthesis_notes.md` — narrative (848 words): what synthesized, glue logic issues found during integration, co-sim results, OpenLane 2 full-flow attempt and Yosys version conflict, scope status

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
Expected output: simulation ends with `PASS`. All four PE results match hand-calculated expected values.

**Dependencies:** Icarus Verilog 12.0 (`sudo apt install iverilog` on Ubuntu 24).
No preprocessing required. All source files are in the repository.

## How to Run Synthesis
**Tool:** Yosys 0.33 (git sha1 2584903a060)
**Install:** `sudo apt install yosys` on Ubuntu 24 (provides Yosys 0.33)

```bash
cd project/m3/synth
yosys run_synth.ys 2>&1 | tee openlane_run.log
```

Expected output: ends with `Total cells: 4305`, `Warnings: 1 unique messages`, exit code 0.
The single warning is a memory-to-register replacement notice (weight_mem unrolled to FFs), which is expected and correct.

**OpenLane 2 version:** 2.3.10
**OpenLane 2 release:** https://github.com/The-OpenROAD-Project/OpenLane/releases/tag/2.3.10
**Config file:** `project/m3/synth/config.json`
**PDK:** sky130A (`sky130_fd_sc_hd` standard cell library)
**Environment variable required:** `PDK_ROOT` must point to sky130A PDK installation for full OpenLane flow

**Note on full OpenLane 2 flow:** The full OpenLane 2.3.10 flow (floorplan through signoff) was attempted on 2026-05-24 but failed at Stage 5 (Yosys.JsonHeader) with `yosys: invalid option -- 'y'` — a known incompatibility between OpenLane 2.3.10 and the system-installed Yosys 0.33. OpenLane 2.3.10 requires Yosys 0.40+. The Yosys 0.33 standalone synthesis completed successfully. Full OpenLane PnR will be completed in M4. See `synthesis_notes.md` for details.
