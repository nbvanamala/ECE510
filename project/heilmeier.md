# Updated Heilmeier Catechism — Edge CNN Accelerator for Industrial AI

## Q1: What are you trying to do?

Design and verify a hardware accelerator in SystemVerilog that accelerates the
cnn_backprop algorithm — specifically the Conv2D._im2col kernel — for CNN inference
on edge devices such as industrial cameras, sensors, and embedded controllers, without
relying on cloud offload or a physical chip. The accelerator will use fixed-point
arithmetic and a parallel systolic array of MAC units to achieve significantly higher
throughput-per-watt than a general-purpose CPU. Correctness will be validated through
simulation in Icarus Verilog and QuestaSim against a NumPy software reference.

## Q2: How is it done today, and what are the limits of the current approach?

cProfile profiling of cnn_backprop across 10 runs on an Intel Core i7-1165G7 shows
that Conv2D._im2col (cnn.py:134) dominates execution: 31.204 s out of 38.724 s total
(80.6%), called 930 times across 30 epochs. The remaining kernels — _conv_forward
(5.861 s), backward (3.219 s), and _col2im (2.418 s) — are all secondary. The limits
are: (1) Python nested loops over output spatial positions make per-call overhead
disproportionate to arithmetic work; (2) all operands are streamed from DRAM on every
call with no data reuse; (3) convolutions are computed sequentially with no spatial
parallelism.

## Q3: What is your approach, and why is it better?

Roofline analysis places Conv2D._im2col at an arithmetic intensity of 2.48 FLOP/byte,
well left of the ridge point, confirming it is deeply memory-bound on the current CPU.
The proposed accelerator replaces this kernel with a weight-stationary systolic array
in SystemVerilog, loading weights once into on-chip SRAM and reusing them across all
output spatial positions. This raises the effective arithmetic intensity to approximately
10 FLOP/byte, crossing the ridge point and moving the kernel into the compute-bound
regime. Fixed-point (INT8/INT16) arithmetic replaces FP64, reducing memory footprint
by 4-8x and enabling denser MAC parallelism. The roofline gap between 2.48 and
10 FLOP/byte directly quantifies the performance headroom the accelerator is designed
to capture.
