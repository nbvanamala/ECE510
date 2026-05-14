# Synthesis Interpretation — compute_core
## ECE510 CF07 | Naveen Babu Vanamala

**Tool:** Yosys 0.65 (yowasp, generic gate library). Full OpenLane 2 was not
available in the current environment (Docker/Nix absent); Yosys synthesis
directly was used as the synthesis step. Reports reference real tool output.

---

### (a) Clock Period and Worst-Case Slack

Clock target: **10 ns (100 MHz)**. Since OpenSTA was not available, slack
was estimated analytically using sky130A HD cell delays. The critical path
through the 8-bit multiplier and 32-bit accumulator is approximately **2.84 ns**
(multiply ~1.8 ns via XOR/XNOR chain + accumulate carry ~0.9 ns + DFF
setup/Tq 0.14 ns). Worst-case setup slack: **≈ +7.16 ns**. The design has
massive positive slack at 100 MHz and can comfortably target 300–350 MHz.

### (b) Critical Path

Source register: `accum_reg` inside any `pe_array[i].u_pe` instance (32-bit
accumulator DFF). Sink register: `accum_out` / `result_data` output register
in `compute_core`. Dominant cell types along the path: `$_XOR_` (915 instances
total) and `$_XNOR_` (326 instances) drive the multiplier tree; `$_NAND_`
(1,446 instances) implements the carry-propagate chain of the 32-bit
accumulator. All four PEs share the same structure, so all four paths are
symmetric with identical worst-case depth.

### (c) Total Cell Area and Top Contributors

Total cell count: **4,039** (generic gate mapping). Top three contributors
by instance count:
1. `$_NAND_` — 1,446 (35.8%) — primary logic fabric for carry chains
2. `$_XOR_` — 915 (22.7%) — INT8 multiplier arithmetic
3. `$_AND_` — 566 (14.0%) — partial-product generation and control

Sequential cell count: 434 flip-flops (`$_SDFFE_PP0P_` 272, `$_SDFF_PP0_`
130, `$_SDFFCE_PN0P_` 24, `$_DFFE_PP_` 8) — all holding accumulator state
and weight-memory registers.

### (d) Violations, Warnings, and Notes

Yosys reported **zero warnings** during elaboration and synthesis. No failed
constraints (design has large positive slack). One structural note: the weight
address port is declared `[1:0]` (hard-coded to NUM\_PE=4); any M3 expansion
beyond 4 PEs will require widening this port. No hold violations are expected
at 100 MHz given the deep positive setup slack.
