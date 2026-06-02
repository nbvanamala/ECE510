# Edge CNN Accelerator for Industrial AI Applications

**Name:** Naveen Babu Vanamala  
**Course:** Hardware for Artificial Intelligence and Machine Learning (ECE 410/510)  
**Term:** Spring 2026

---

## Milestone 4 — Final Submission

**M4 deliverables:** [`project/m4/`](project/m4/)  
**Design justification report:** [`project/m4/report/design_justification.pdf`](project/m4/report/design_justification.pdf)  
**M4 file catalog:** [`project/m4/README.md`](project/m4/README.md)

### Key results (M4)
| Metric | Value |
|--------|-------|
| RTL | 4-PE weight-stationary systolic array, AXI4-Lite, INT8, SystemVerilog |
| Simulation | PASS — `project/m4/sim/final_run.log` |
| Synthesis | sky130A, 1,763 stdcells, 20,656 µm², 2.31 mW, 100 MHz (WNS=0) |
| HW throughput | 60.0 MFLOPs/s (cosim, 120 cycles/patch) |
| SW baseline | 5.91 MFLOPs/s (Python im2col loop, M1) |
| Speedup | **10.15×** |

---

## Project Summary

This project implements a hardware accelerator for 3×3 INT8 convolutional
neural network inference targeting the sky130A open-source PDK. The accelerator
uses a weight-stationary dataflow with four parallel processing elements (PEs)
connected via an AXI4-Lite host interface.

---

## Repository Structure

```
project/
├── heilmeier.md          Project proposal
├── m1/                   Software baseline, roofline analysis, interface selection
├── m2/                   RTL (conv_pe, compute_core, interface), precision analysis
├── m3/                   Integrated top module, co-simulation, OpenLane 2 synthesis
└── m4/                   FINAL: RTL, TB, sim, synth, benchmark, report
codefest/
├── cf01/ … cf09/         Weekly codefest deliverables
```

---

## Prior Milestone Notes

**M2** introduced the INT8 conv_pe and compute_core, verified with cocotb.  
**M3** integrated the AXI4-Lite interface, ran full co-simulation (PASS), and
completed OpenLane 2 synthesis through global placement + STA on sky130A.  
**M4** packages final RTL (identical to M3), extracts real OpenLane 2 timing/
area/power numbers, and adds the benchmark comparison and design justification report.
