# M3 Synthesis Plan — compute_core
## ECE510 CF07 | Naveen Babu Vanamala | Option A

**Synthesis result:** 7,274 cells, 53,346 µm² area, WNS +2.32 ns
nominal corner (nom_tt_025C_1v80), WNS -3.01 ns nom_ss corner
(nom_ss_100C_1v60), overall worst WNS -3.17 ns (max_ss_100C_1v60).

**Changes for M3:**

1. **Add proper SDC file.** OpenLane used generic fallback constraints.
   A real SDC with explicit clock definition will improve timing accuracy
   and may reduce the ss corner violations.

2. **Pipeline the critical path.** The -3.01 ns nom_ss violation
   (overall worst -3.17 ns at max_ss) comes from the 8-bit multiply
   plus 32-bit accumulate chain. One pipeline register between multiply
   and accumulate will cut the path.

3. **Keep 100 MHz clock target.** Nominal corner closes at +2.32 ns
   slack. Fix ss violations before raising frequency.

4. **Keep INT8 precision.** 53,346 µm² is well within sky130A capacity.
   No precision reduction needed.
