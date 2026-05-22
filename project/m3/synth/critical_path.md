# Critical Path Analysis — Edge CNN Accelerator (top)
## Tool: Yosys 0.33 structural analysis
## Design: top | Clock: 10ns (100MHz)

## Critical Path

**Start point:** `u_interface/u_slave/pixel_out` — the registered pixel output
of the AXI4-Lite slave interface. This register is updated every time the host
writes to the PIXEL_IN register (address 0x00) via AXI4-Lite.

**End point:** `u_core/pe_array[0]/u_pe/accum_reg` — the 32-bit accumulator
flip-flop inside each conv_pe instance. This register holds the running sum of
pixel times weight products across all 9 taps of the 3x3 convolution kernel.

**Logic stages between start and end:**
1. pixel_out FF Q output (~0.15 ns)
2. Broadcast wire to conv_pe pixel_in (0 ns)
3. Signed 8x8 multiplier — mapped to Wallace tree adder (~0.80 ns, ~8 logic levels)
4. Sign extension from 16b to 32b (wiring only, 0 ns)
5. 32-bit ripple-carry adder: accum_reg + product_ext (~1.60 ns, 32 full-adder stages)
6. Mux select driven by tap_count comparator (~0.10 ns)
7. accum_reg setup time (~0.10 ns)

**Total estimated delay: 2.75 ns | Estimated WNS: +7.25 ns**

## Why This Is the Critical Path

This path is the critical path because it contains the longest combinational
chain in the design. The 32-bit ripple-carry adder is the dominant stage: it
chains 32 full-adder cells sequentially, where each carry must propagate to
the next stage before that stage can compute its sum. At approximately 50 ps
per full-adder stage in sky130_fd_sc_hd, the 32-stage chain contributes
roughly 1.60 ns of combinational delay. The 8x8 signed multiplier adds another
~0.80 ns. All other paths in the design (AXI FSM transitions, weight address
counter, done_in wire) are much shorter at under 0.5 ns and do not come close
to the 10 ns clock period.

## What Would Shorten This Path

The most effective fix is to pipeline the accumulator: insert a register
between the multiplier output and the adder input. This splits the 2.75 ns
path into two stages of ~1.4 ns each, enabling ~700 MHz operation at the cost
of one extra cycle of latency per tap (10 cycles total instead of 9 for a 3x3
patch). A second option is to replace the ripple-carry adder with a
carry-lookahead adder (CLA), which reduces the 32-stage carry chain to roughly
log2(32) = 5 stages, cutting the adder delay from 1.60 ns to about 0.25 ns.
A third option is to reduce ACCUM_WIDTH from 32 bits to 18 bits, since the
maximum accumulation for KERNEL_SIZE=9 with INT8 inputs is 9 x 127 x 127 =
144,963, which fits in 18 bits and would cut the adder depth nearly in half.
