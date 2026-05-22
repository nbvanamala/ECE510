# Milestone 3 - Edge CNN Accelerator Integration
## ECE510 Spring 2026 - Naveen Babu Vanamala

## File Catalog
- README.md - this file, catalogs all M3 files and subfolders
- rtl/top.sv - integrated top module connecting M2 interface and compute core, with port header comments and glue logic
- tb/tb_top.sv - end-to-end testbench, AXI4-Lite only, no direct compute core access
- sim/cosim_run.log - simulation transcript ending in PASS
- sim/cosim_waveform.png - waveform image showing 3 annotated regions
- sim/cosim_waveform.vcd - raw VCD waveform dump from simulation
- synth/synth.ys - Yosys synthesis script
- synth/config.json - OpenLane 2 configuration (clock 10ns, sky130A PDK)
- synth/openlane_run.log - full Yosys synthesis log, 3766 cells, zero errors
- synth/timing_report.txt - critical path analysis, estimated slack +7.95ns at 100MHz
- synth/area_report.txt - cell count and module-level area breakdown
- synth/power_report.txt - power estimate 0.57mW, OpenLane2 flow attempt documented
- synth/critical_path.md - critical path: pixel_out register to conv_pe accum_reg
- synthesis_notes.md - narrative (662 words) of what synthesized, glue logic issues, and scope status

## How to Run Co-Simulation
Simulator: Icarus Verilog 12.0 (iverilog -V)
Dependencies: iverilog, vvp (both in iverilog package)

cd project/m3/sim
iverilog -g2012 -o tb_top ../rtl/top.sv ../../m2/rtl/conv_pe.sv ../../m2/rtl/compute_core.sv ../../m2/rtl/interface.sv ../tb/tb_top.sv
vvp tb_top | tee cosim_run.log

Expected last line: PASS

## How to Run Synthesis
Tool: Yosys 0.33 (git sha1 2584903a060)
Note: This is the Yosys front-end step of the OpenLane 2 flow.
Full OpenLane 2 (placement + routing + STA) requires sky130A PDK installation.
OpenLane 2 install: https://github.com/The-OpenROAD-Project/OpenLane2
Config file: project/m3/synth/config.json

cd project/m3/synth
yosys synth.ys | tee openlane_run.log

Expected output: 3766 cells at end of log.
