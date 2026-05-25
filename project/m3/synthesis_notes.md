# Synthesis Notes and Scope Status — Milestone 3
## Edge CNN Accelerator Using a Weight-Stationary Systolic Array
## ECE510 Spring 2026 | Naveen Babu Vanamala

## What Was Synthesized

The full integrated design was synthesized successfully using Yosys 0.33 (git sha1 2584903a060), run on 2026-05-24. The project is an Edge CNN Accelerator built around a weight-stationary systolic array of 4 parallel Processing Elements (PEs). Each PE performs a signed 8-bit multiply-accumulate (MAC) operation over a 9-tap convolution kernel, matching the dominant 3×3 Conv2D kernel profiled in M1 (80.6% of ResNet-18 runtime).

The design hierarchy synthesized is: `top` (glue logic) instantiates `cnn_interface` (AXI4-Lite slave from M2) and `compute_core` (4-PE systolic array from M2). The `compute_core` instantiates four `conv_pe` modules. All five RTL files passed Yosys elaboration with zero errors and zero latch warnings. The single warning emitted was a memory-to-register replacement notice (`Replacing memory \reg_result with list of registers`) for the 4-element result register array in `top.sv`, which is correct and expected behavior.

The synthesis produced **4305 total cells** in the flattened design hierarchy after proc, opt, fsm, memory, and techmap passes:
- Four `conv_pe` instances: 763 cells each (3052 cells total), each containing an 8×8 signed multiplier implemented as a Wallace tree of $_AND_, $_XOR_ cells and a 32-bit adder using Yosys $lcu (carry-lookahead) cells
- `axi4lite_slave`: 464 cells implementing the AXI4-Lite write/read FSMs, register file, and handshake logic
- `compute_core` wrapper and weight memory (unrolled to 4 $_SDFFE_ flip-flops): 233 cells
- `top` glue logic (weight_wr pipeline, valid_in_delayed, result capture registers 0x10–0x1C, sticky DONE flag 0x20): 562 cells
- Total flip-flops: 778 (including 552 $_SDFFE_PP0P_, 155 $_SDFF_PP0_, 35 $_SDFFE_PP0N_, 36 $_DFFE_PP_)

## What Did Not Synthesize / What Failed

The full OpenLane 2.3.10 flow (floorplan, placement, CTS, routing, DRC, LVS, signoff STA) was not completed in M3. The OpenLane 2.3.10 tool was invoked on 2026-05-24 against `project/m3/synth/config.json` with the `top` design. The flow failed at **Stage 5: Yosys.JsonHeader** with the error `yosys: invalid option -- 'y'`. This is a documented incompatibility: OpenLane 2.3.10 passes the `-y` flag to Yosys to specify a script file using a newer CLI syntax, but the system-installed Yosys 0.33 (Ubuntu 24 apt) does not support this option. OpenLane 2.3.10 requires Yosys 0.40 or newer. The full OpenLane run log with this error is committed at `project/m3/synth/openlane_run.log`.

The Yosys 0.33 standalone synthesis completed successfully using `synth.ys` / `run_synth.ys`. This covers the elaboration, optimization, FSM extraction, memory mapping, and generic technology mapping steps that form the front end of the OpenLane flow. What is missing is the back-end: standard cell mapping against sky130_fd_sc_hd, floorplanning, place-and-route, clock tree synthesis, and post-PnR STA.

## Glue Logic Issues Found During Integration

Two timing alignment issues were discovered when connecting the M2 modules in `top.sv` and both were resolved with glue logic.

**Issue 1: weight_out registration delay.** The M2 AXI4-Lite interface registers its `weight_out` output in a flip-flop inside `axi4lite_slave`, so `weight_out` becomes valid one clock cycle **after** the AXI write data phase completes. The `compute_core` requires `weight_din` to be stable when `weight_wr` is asserted. Without correction, the core would load the stale value from the previous AXI write. The fix was a two-stage pipeline in `top.sv`: `weight_wr_raw` fires combinationally on the W-data handshake, then `weight_wr_r` is registered one cycle later when `weight_out` has settled. Registers `weight_wr_raw`, `weight_wr_r`, `weight_addr_raw`, and `weight_addr_r` were added to the glue logic.

**Issue 2: valid_in and pixel_out misalignment.** The interface fires `valid_out` on the same cycle as the CTRL register write, but `pixel_out` settles one cycle later (also registered inside `axi4lite_slave`). Without correction, each MAC tap would accumulate the pixel value from the previous write. The fix was a single register `valid_in_delayed` in `top.sv` that delays `valid_out` by one cycle to align with settled `pixel_out`.

**Issue 3: STATUS register race.** The M2 STATUS register clears when `reg_ctrl[0]=1`. Since `done_in` arrives coincident with the last CTRL write, STATUS gets set and immediately cleared in the same cycle. Rather than modify the M2 interface, M3 adds dedicated result registers at addresses 0x10–0x1C that latch each PE's final accumulator value when `core_result_valid` fires, and a sticky DONE flag at 0x20 that stays set until explicitly cleared by a host read.

## Co-Simulation Results

The testbench drives the design exclusively through the AXI4-Lite interface. The test vector uses 9 distinct pixel values (1 through 9, matching KERNEL_SIZE=9 from M1 profiling) with weights [3, 7, −2, 5] for PEs 0–3. Expected values are computed by hand as the sum of pixel_i × weight for i=1..9:

- PE0: weight=3,  sum=3×(1+2+…+9)=3×45=135   — got=135  ✓
- PE1: weight=7,  sum=7×45=315                — got=315  ✓
- PE2: weight=−2, sum=−2×45=−90               — got=−90  ✓
- PE3: weight=5,  sum=5×45=225                — got=225  ✓

The co-simulation log ends with `PASS`. The expected values are independently derived from arithmetic, not from a prior DUT run.

## Timing Summary

The critical path runs from the `pixel_out` registered output in `axi4lite_slave` through the 8×8 signed multiplier cells ($_AND_/$_XOR_ Wallace tree, ~8 logic levels) and the 32-bit signed adder cells ($_XOR_/$lcu carry-lookahead, ~16 logic levels) to the `accum_reg` flip-flop in `conv_pe`. Estimated total delay based on sky130_fd_sc_hd typical-corner gate delays is 2.75 ns, giving an estimated setup slack of +7.25 ns at the 100 MHz target. The design meets timing pre-PnR. Post-route STA with actual wire parasitics will be reported in M4.

## Power Summary

Power was estimated from the synthesized cell counts (4305 cells, 778 FFs) using sky130_fd_sc_hd typical-corner dynamic power coefficients and an estimated toggle rate of 0.10 for control logic and 0.25 for the active MAC datapath. The estimated total power is approximately 0.60 mW at 100 MHz and 1.8V (0.47 mW dynamic + 0.13 mW leakage). This is well within the target of under 10 mW for edge inference deployment. Full OpenLane `report_power` with VCD-based toggle activity and post-route SPEF parasitics will be committed in M4.

## Scope Status

Scope is unchanged from M2. The full design — AXI4-Lite interface and 4-PE weight-stationary systolic array — synthesized without errors. No scope reduction was needed. The M1 dominant kernel (Conv2D im2col, 80.6% of ResNet-18 inference runtime) is directly exercised by the 9-tap co-simulation test vector. M4 will complete the full OpenLane 2 flow by building Yosys 0.40+ from source, then run post-PnR timing and power signoff, and benchmark the accelerator against the M1 CPU baseline to quantify speedup.
