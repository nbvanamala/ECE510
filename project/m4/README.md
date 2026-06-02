# M4 — Final Deliverable Package
## Edge CNN Accelerator | ECE510 Spring 2026 | Naveen Babu Vanamala

Design justification report: [report/design_justification.pdf](report/design_justification.pdf)

---

## File Catalog

### 1. Source Code (`rtl/`)

| File | Description | Checklist item |
|------|-------------|----------------|
| `rtl/top.sv` | Integrated top module: AXI4-Lite write pipeline, weight staging, result capture, DONE flag. Identical to `project/m3/rtl/top.sv` — the version that was synthesized and benchmarked. | §2 Final RTL |
| `rtl/interface.sv` | AXI4-Lite slave (`axi4lite_slave`) + wrapper (`cnn_interface`). M3 version adds result read-back at 0x10. Identical to `project/m3/rtl/interface.sv`. | §2 Final RTL |
| `rtl/compute_core.sv` | Weight-stationary parallel PE array core: 4 conv_pe instances, weight memory FFs, result packing. From `project/m2/rtl/compute_core.sv` (unchanged). | §2 Final RTL |
| `rtl/conv_pe.sv` | Single INT8 convolution processing element: 8×8 signed MAC, 32-bit accumulator, KERNEL_SIZE tap counter. From `project/m2/rtl/conv_pe.sv` (unchanged). | §2 Final RTL |

**Diff from M3:** No RTL changes. The M4 RTL is identical to M3. The three planned improvements (streaming FIFO, 8-PE expansion, full OpenLane PnR) are documented in §9 of the design justification report under "What did not work / future work."

### 2. Testbench (`tb/`)

| File | Description | Checklist item |
|------|-------------|----------------|
| `tb/tb_top.sv` | Self-contained AXI4-Lite testbench. Writes 4 weights, streams 9 INT8 pixel taps, polls DONE, reads back 4 PE results. Verifies PE0–PE3 against golden values. Prints PASS/FAIL. Identical to `project/m3/tb/tb_top.sv`. | §2 Final testbench |

**How to run** (Icarus Verilog):
```sh
iverilog -g2012 -o sim_out tb/tb_top.sv rtl/top.sv rtl/interface.sv rtl/compute_core.sv rtl/conv_pe.sv
vvp sim_out
```

### 3. Simulation Outputs (`sim/`)

| File | Description | Checklist item |
|------|-------------|----------------|
| `sim/final_run.log` | Icarus Verilog simulation log. Shows 3 complete weight-load + pixel-stream + result-readback cycles. All 4 PEs match golden expected values. Ends with `PASS`. | §2 Sim log (PASS) |
| `sim/final_waveform.png` | Annotated waveform from GTKWave showing AXI4-Lite write transactions (PIXEL_IN, WEIGHT_IN, CTRL), valid_in pulse to compute_core, and result_valid assertion. | §2 Final waveform |

### 4. Synthesis Results (`synth/`)

| File | Description | Checklist item |
|------|-------------|----------------|
| `synth/config.json` | OpenLane 2 configuration: top module, 4 source files, sky130A PDK, sky130_fd_sc_hd std-cell lib, 10 ns clock, AREA 0 strategy, 40% core utilization target. | §3 Config |
| `synth/openlane_run.log` | OpenLane 2 flow log (captured from `project/m3/synth/runs/RUN_2026-05-20_22-44-53/flow.log`). Shows all 43 steps from Verilator lint through TritonRoute detailed routing. | §3 Run log |
| `synth/timing_report.txt` | OpenROAD STA results (STAMidPNR-3, post-global-routing, nom_tt_025C_1v80). WNS=0 setup, WNS=0 hold. Worst setup slack +4.062 ns at 100 MHz. No violations. | §3 Timing |
| `synth/area_report.txt` | OpenROAD floorplan metrics (sky130A stdcells). Die=59,334 µm², stdcell area=20,656 µm², 1,763 cells, 40.3% utilization. Dominant: conv_pe×4 (~52%). | §3 Area |
| `synth/power_report.txt` | OpenROAD report_power (STAMidPNR-3, nom_tt_025C_1v80). Total=2.310 mW: sequential 1.289 mW (55.8%), clock 0.872 mW (37.8%), comb 0.149 mW (6.5%). | §3 Power |

### 5. Benchmark (`bench/`)

| File | Description | Checklist item |
|------|-------------|----------------|
| `bench/benchmark.md` | Throughput, speedup, and energy comparison. HW: 47.7 MFLOPs/s (151 cycles/patch, measured cosim). SW: 5.91 MFLOPs/s (Python loop). Speedup: 8.07×. Energy: ~3.14 µJ vs ~307 mJ. | §4 Benchmark |
| `bench/benchmark_data.csv` | Raw measurement data backing all numbers in benchmark.md and the report. One row per metric with value, unit, and source reference. | §4 Raw data |
| `bench/roofline_final.png` | Roofline plot on sky130A axes (FLOP/byte vs GFLOPs/s, log scale). Shows hardware roofline, SW baseline point (5.91 MFLOPs/s, 2.48 AI), and M4 measured HW point (47.7 MFLOPs/s, 2.48 AI, 151 cycles/patch cosim). | §4 Roofline |

### 6. Design Justification Report (`report/`)

| File | Description | Checklist item |
|------|-------------|----------------|
| `report/design_justification.pdf` | 9-section engineering report (~4,200 words). Sections: Problem & Motivation, Roofline Analysis, Precision & Data Format, Dataflow & Architecture, Hardware Interface, Verification, Synthesis Results, Benchmark Results, What Did Not Work. | §5 Report |
| `report/design_justification.md` | Markdown source for the PDF. Converted to PDF using `build_pdf.py`. | §5 Report source |
| `report/build_pdf.py` | Python script (ReportLab) that generates design_justification.pdf from design_justification.md. Run: `python3 report/build_pdf.py`. | §5 Build tool |
| `report/figures/block_diagram.png` | System block diagram (Figure 1 in report). | §5 Figures |
| `report/figures/dataflow_diagram.png` | Weight-stationary dataflow diagram (Figure 2 in report). | §5 Figures |
| `report/figures/final_waveform.png` | Annotated AXI4-Lite co-simulation waveform (Figure 3 in report). | §5 Figures |
| `report/figures/roofline_final.png` | Final roofline plot with M4 measured point (Figure 4 in report). | §5 Figures |
