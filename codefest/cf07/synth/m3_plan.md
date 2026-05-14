# M3 Synthesis Plan — compute_core
## ECE510 CF07 | Naveen Babu Vanamala | Option A (project core)

**Synthesis result summary:** 4,039 generic cells, critical path ≈ 2.84 ns,
estimated WNS +7.16 ns at 100 MHz.

**What will change for M3:**

1. **Raise clock target to 250 MHz (4 ns period).** The +7.16 ns slack at
   100 MHz confirms the current design is massively underclocked. At 250 MHz
   estimated WNS is still positive (~+1.2 ns), which provides synthesis
   closure margin.

2. **Scale to NUM\_PE = 8 (from 4).** Cell count scales linearly with PE
   count. At 4,039 cells for 4 PEs, 8 PEs ≈ 8,000 cells — still small for
   sky130A. Area concern is negligible; the additional weight-address bit
   (`[2:0]`) must be added to avoid port truncation.

3. **Run full OpenLane 2 (Docker) for M3.** The current Yosys-only run lacks
   real sky130A area (μm²) and STA. M3 will use a machine with Docker to
   produce `final/reports/metrics.csv` with actual place-and-route results
   and OpenROAD STA numbers, replacing the analytical timing estimates here.

4. **Keep INT8 precision.** The 4,039-cell count is well within manageable
   range; no precision reduction is needed to close timing at the new target.
