# Roofline Analysis — CF09 Task 9
## ECE510 Spring 2026 | Naveen Babu Vanamala

The accelerator lands at **60 MFLOPs/s** (measured, cosim) at AI = 2.48
FLOPs/byte — 5.5× below the sky130A bandwidth ceiling of 330 MFLOPs/s and
13× below the 800 MFLOPs/s compute ceiling. The design is neither
bandwidth-bound nor compute-bound: it is **AXI-overhead-bound**. Each patch
invocation requires 4 weight-load writes plus 9 pixel writes via AXI4-Lite
(3 bus cycles each), totalling ~111 overhead cycles before any MAC output is
produced. Of the 120 total cycles per patch, only 9 perform MAC accumulation
(7.5% utilization). The dominant uncertainty in converting the cosim
measurement to steady-state throughput is reset overhead: 6 cycles per test
invocation inflate latency from 114 to 120 cycles. Removing reset alone
recovers less than 5%; closing the full 5.5× gap requires replacing the
per-patch AXI write sequence with a burst or streaming interface that pipelines
pixel delivery with MAC accumulation.
