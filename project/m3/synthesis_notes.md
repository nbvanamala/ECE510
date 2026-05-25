# Synthesis Notes and Scope Status — Milestone 3
## Edge CNN Accelerator Using a Weight-Stationary Systolic Array
## ECE510 Spring 2026 | Naveen Babu Vanamala

## What Was Synthesized

The full integrated design was synthesized successfully using Yosys 0.33. The project is an Edge CNN Accelerator built around a weight-stationary systolic array of 4 parallel Processing Elements (PEs). Each PE performs a signed 8-bit multiply-accumulate (MAC) operation over a 9-tap convolution kernel matching the 3x3 kernel profiled in M1. The design hierarchy is: top (glue logic) instantiates cnn_interface (AXI4-Lite slave from M2) and compute_core (4-PE systolic array from M2). The compute_core instantiates four conv_pe modules. All four RTL files passed Yosys elaboration with zero errors and zero latch warnings.

The synthesis completed with 4305 total cells in the flattened design hierarchy. The dominant area consumers are the four conv_pe instances (763 cells each, 3052 cells total), each containing a signed 8x8 multiplier and a 32-bit accumulator register. The AXI4-Lite slave contributed 464 cells. The compute_core wrapper added 233 cells and the top-level glue logic added 562 cells including the result capture registers and the sticky DONE flag at address 0x20.

## What Did Not Synthesize

The full OpenLane 2 flow (floorplan, placement, CTS, routing, DRC, LVS, signoff STA) was not completed in M3 because OpenLane 2 requires a full sky130A PDK installation. Only Yosys 0.33 was available as a standalone tool. Yosys is the front-end synthesis step of the OpenLane 2 flow and it completed successfully with zero errors and zero problems. The remaining OpenLane 2 steps will be completed in M4.

## Glue Logic Issues Found During Integration

Two timing alignment issues were discovered when connecting the M2 modules in top.sv.

First, the weight_out registration delay. The M2 AXI4-Lite interface registers its weight_out output, meaning weight_out becomes valid one clock cycle AFTER the AXI write data phase completes. The compute_core requires weight_din to be stable when weight_wr is asserted. Without correction, the core would load a stale weight value. The fix was a two-stage pipeline in top.sv: weight_wr_raw fires on the W-data phase, then weight_wr_r is registered one cycle later to align with the now-stable weight_out signal. This required adding registers weight_wr_raw, weight_wr_r, weight_addr_raw, and weight_addr_r in the glue logic.

Second, the valid_in and pixel_in misalignment. The interface fires valid_out on the same cycle as the CTRL write, but pixel_out settles one cycle later. Without correction, each computation tap would accumulate the pixel value from the previous write, not the current one. The fix was a single register valid_in_delayed in top.sv that delays valid_out by one cycle to align with the settled pixel_out.

A third issue was the STATUS register race condition. The M2 interface clears STATUS when reg_ctrl[0]=1. Since done_in arrives at the same cycle as the last CTRL write, STATUS gets set and immediately cleared. For M3, results are captured in dedicated registers at 0x10-0x1C and a sticky DONE flag at 0x20. This will be cleaned up in M4.

## Co-Simulation Results

The testbench drives the design exclusively through the AXI4-Lite interface with no direct compute-core port access. The test vector used 9 distinct pixel values (pixels 1 through 9) matching KERNEL_SIZE=9 from M1, with weights [3, 7, -2, 5] for the four PEs. Expected values computed as sum(pixel_i x weight) for i=1..9:

- PE0: weight=3,  expected=135, got=135 — OK
- PE1: weight=7,  expected=315, got=315 — OK
- PE2: weight=-2, expected=-90, got=-90  — OK
- PE3: weight=5,  expected=225, got=225  — OK

The co-simulation log ends with PASS.

## Timing Summary

The critical path runs from pixel_out register in the AXI4-Lite slave through the 8x8 signed multiplier and 32-bit ripple-carry adder to accum_reg in conv_pe. Estimated total delay is 2.75 ns, giving setup slack of +7.25 ns at 100 MHz. Timing is met. Full post-PnR STA is deferred to M4.

## Power Summary

Estimated power is 0.57 mW at 100 MHz, 1.8V based on manual switching activity estimation. Full OpenLane 2 report_power will be completed in M4.

## Scope Status

Scope is unchanged from M2. The full design including the AXI4-Lite interface and the 4-PE weight-stationary systolic array synthesized without errors. No scope reduction was needed. The M1 dominant kernel (Conv2D im2col, 80.6% of runtime) is directly exercised by the 9-tap co-simulation test vector. M4 will complete the full OpenLane 2 flow and benchmark the accelerator against the M1 CPU baseline to quantify the speedup of the weight-stationary systolic array.

## OpenLane 2 Full Flow Attempt

The full OpenLane 2.3.10 flow was attempted on 2026-05-24. The flow failed at
Stage 5 (Yosys.JsonHeader) with the error: "yosys: invalid option -- 'y'".
This is a known incompatibility between OpenLane 2.3.10 and the system Yosys
0.33. OpenLane 2.3.10 requires Yosys 0.40+ for its JsonHeader step. The Ubuntu
24 apt repository only provides Yosys 0.33 as the latest version. Installing
a newer Yosys requires building from source which is outside M3 scope.

The Yosys 0.33 standalone synthesis (synth.ys) completed successfully with
4305 cells, 0 errors, and 0 latches. The full OpenLane PnR flow
(placement, routing, STA, power) will be completed in M4 after resolving
the Yosys version conflict by building Yosys 0.40+ from source.
