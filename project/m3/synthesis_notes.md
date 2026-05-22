# Synthesis Notes - Milestone 3
## Edge CNN Accelerator - ECE510 Spring 2026
## Naveen Babu Vanamala

## What Synthesized
The full integrated design synthesized using Yosys 0.33 with zero errors.
Hierarchy: top -> cnn_interface -> axi4lite_slave, and top -> compute_core -> conv_pe x4.
Total cells: 3766. Flip-flops: 605. No latches inferred.

## What Did Not Work
OpenLane 2 full flow (placement, routing, STA) was not run because it requires
a full sky130A PDK installation. Yosys synthesis (the front-end step) completed
successfully. Full OpenLane 2 will be run in M4.

## Glue Logic Issues Found During Integration
Two timing alignment issues were found and fixed in top.sv:

1. weight_out registration delay: the interface registers weight_out one cycle
after the AXI write completes. Fixed by delaying weight_wr by one clock cycle
using weight_wr_raw -> weight_wr_r pipeline registers.

2. valid_in / pixel_in misalignment: valid_out fires on the CTRL write cycle
but pixel_out settles one cycle later. Fixed by adding valid_in_delayed register
in top.sv to delay valid_in by one cycle.

3. STATUS register conflict: the M2 interface clears STATUS when reg_ctrl[0]=1,
which conflicts with done_in arriving at the same time as the last CTRL write.
Results are read from result_out directly. Will fix in M4.

## Co-Simulation Results
All four PE outputs correct:
PE0: 9 x 4 x 3 = 108  OK
PE1: 9 x 4 x 7 = 252  OK
PE2: 9 x 4 x -2 = -72 OK
PE3: 9 x 4 x 5 = 180  OK
Final log line: PASS

## Scope Status
Scope unchanged from M2. Full design synthesized without errors.
The M1 dominant kernel (Conv2D im2col, 80.6% of runtime) is directly
exercised by the 9-tap co-simulation test vector.

M4 plans: full OpenLane 2 synthesis, STATUS register fix, power analysis,
and benchmarking against M1 software baseline.
