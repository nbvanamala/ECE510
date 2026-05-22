# Synthesis Notes and Scope Status — Milestone 3
## Edge CNN Accelerator for Industrial AI Applications
## ECE510 Spring 2026 | Naveen Babu Vanamala

## What Was Synthesized

The full integrated design was synthesized successfully using Yosys 0.33, which is the front-end synthesis step of the OpenLane 2 flow. The design hierarchy is: top (glue logic) instantiates cnn_interface (AXI4-Lite slave from M2) and compute_core (4-PE systolic array from M2). The compute_core in turn instantiates four conv_pe modules. All four RTL files passed Yosys elaboration with zero errors and zero latch warnings.

The synthesis completed with 3766 total cells in the flattened hierarchy. The dominant area consumers are the four conv_pe instances (4 x 763 = 3052 cells combined), each containing a signed 8x8 multiplier and a 32-bit accumulator register. The AXI4-Lite slave contributed 464 cells due to the registered FSM and multiple 32-bit data registers. The compute_core wrapper added 233 cells, and the top-level glue logic added only 23 cells.

## What Did Not Synthesize

The full OpenLane 2 flow (placement, routing, signoff STA) was not completed because OpenLane 2 requires a full sky130A PDK installation with the standard cell library, which was not available in the current environment. Only Yosys 0.33 was available as a standalone tool. The Yosys synthesis step is the first step of the OpenLane 2 flow and it completed successfully. The remaining steps (floorplan, placement, CTS, routing, DRC, LVS) will be completed in M4 after installing OpenLane 2 with the sky130A PDK.

## Glue Logic Issues Found During Integration

Two timing alignment issues were discovered when connecting the M2 modules together in top.sv.

First, the weight_out registration delay. The M2 AXI4-Lite interface registers its weight_out output, meaning weight_out becomes valid one clock cycle AFTER the AXI write data phase completes. The compute_core requires weight_din to be stable when weight_wr is asserted. Without correction, the core would load a stale weight value (the previous write, not the current one). The fix was a two-stage pipeline in top.sv: weight_wr_raw fires on the W-data phase, then weight_wr_r is registered one cycle later, delayed to align with the now-stable weight_out signal. This required adding two registers (weight_wr_raw and weight_wr_r) and two address registers (weight_addr_raw and weight_addr_r) in the glue logic.

Second, the valid_in and pixel_in misalignment. The interface fires valid_out on the same cycle as the CTRL write, but pixel_out (which becomes pixel_in for the core) settles one cycle later due to the same registered output pattern. Without correction, each computation tap would accumulate the pixel value from the PREVIOUS write, not the current one. For example, tap 0 would accumulate pixel=0 (reset value) instead of pixel=4. The fix was a single register valid_in_delayed in top.sv that delays valid_out by one cycle, aligning it with the settled pixel_out.

A third issue was discovered with the STATUS register. The M2 interface clears STATUS when reg_ctrl[0]=1. Since done_in arrives at the same cycle as the last CTRL write, STATUS gets set and then immediately cleared. This means the host cannot reliably poll STATUS. For M3, results are read directly from the result_out port. This will be fixed in M4 by adding a sticky STATUS register that only clears on an explicit write of 0.

## Co-Simulation Results

All four PE outputs matched the independent Python reference exactly. The test vector used pixel=4 for all 9 taps (matching the 3x3 KERNEL_SIZE=9 from M1 profiling), with weights [3, 7, -2, 5] for the four output channels. Expected values computed as 9 x 4 x weight: PE0=108, PE1=252, PE2=-72, PE3=180. All four matched. The co-simulation log ends with PASS.

## Scope Status

Scope is unchanged from M2. The full design including the AXI4-Lite interface and the 4-PE systolic array synthesized without errors. No scope reduction was needed. The M1 dominant kernel (Conv2D im2col, 80.6 percent of runtime) is directly exercised by the 9-tap co-simulation test vector. M4 will run the full OpenLane 2 flow, fix the STATUS register, and benchmark against the M1 software baseline.
