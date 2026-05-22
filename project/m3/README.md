# Milestone 3 - Edge CNN Accelerator Integration
## ECE510 Spring 2026 - Naveen Babu Vanamala

## File Catalog
- README.md - this file, catalogs all M3 files
- rtl/top.sv - integrated top module connecting M2 interface and compute core
- tb/tb_top.sv - end-to-end testbench, AXI4-Lite only, no direct core access
- sim/cosim_run.log - simulation transcript ending in PASS
- sim/cosim_waveform.vcd - waveform dump from simulation
- synth/synth.ys - Yosys synthesis script
- synth/config.json - OpenLane 2 configuration
- synth/openlane_run.log - full Yosys synthesis log, 3766 cells
- synth/timing_report.txt - critical path analysis, slack +7.95ns
- synth/area_report.txt - cell count breakdown
- synth/power_report.txt - power estimate 0.57mW
- synth/critical_path.md - critical path identification
- synthesis_notes.md - narrative of what worked and what did not

## How to Run Co-Simulation
Simulator: Icarus Verilog 12.0
cd project/m3/sim
iverilog -g2012 -o tb_top ../rtl/top.sv ../../m2/rtl/conv_pe.sv ../../m2/rtl/compute_core.sv ../../m2/rtl/interface.sv ../tb/tb_top.sv
vvp tb_top | tee cosim_run.log

## How to Run Synthesis
Tool: Yosys 0.33
cd project/m3/synth
yosys synth.ys | tee openlane_run.log
