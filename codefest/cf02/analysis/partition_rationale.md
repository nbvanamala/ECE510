# HW/SW Partition Rationale — Edge CNN Accelerator

## (a) Kernel to accelerate in hardware and roofline justification

The dominant kernel identified via cProfile is `Conv2D._im2col`, which accounts for approximately
72% of total training runtime (27.9 s out of 38.7 s). Roofline analysis on the Apple M2 laptop CPU
places this kernel at an arithmetic intensity of 2.48 FLOP/byte, well below the ridge point of
18 FLOP/byte. This confirms the kernel is deeply memory-bound on general-purpose hardware. The
bottleneck is the nested Python loop structure over output spatial positions, which generates
excessive DRAM traffic with no cache reuse. The convolution kernel is therefore the clear candidate
for hardware acceleration. Its regular, data-parallel structure — a tiled matrix-matrix
multiplication after im2col — maps directly onto fixed-function parallel MAC units in a custom
accelerator using a weight-stationary dataflow.

## (b) What the software baseline will continue to handle

The software baseline will continue to manage training loop orchestration, loss computation,
parameter updates (SGD optimizer), data loading and preprocessing, and activation functions
(ReLU, softmax). These components are either control-flow-heavy, sequentially dependent, or
low-compute relative to convolution, making them poor candidates for custom hardware. The backward
pass (_col2im) may also remain in software initially, as it contributes only ~11% of runtime.

## (c) Interface bandwidth required to avoid becoming interface-bound

For a target accelerator operating at 500 GFLOP/s with a target arithmetic intensity of
10 FLOP/byte (the hypothetical HW design point on the roofline), the required interface bandwidth
is:

    Required BW = Peak GFLOP/s / Target AI = 500 / 10 = 50 GB/s

The accelerator must therefore sustain at least 50 GB/s of on-chip memory bandwidth to remain
compute-bound. This is achievable with a scratchpad SRAM and weight-stationary dataflow, where
weights are loaded once and reused across all output spatial positions — consistent with
established edge accelerator designs like Eyeriss.

## (d) Current bound classification and expected change with the accelerator

On the current Apple M2 CPU, the Conv2D kernel is memory-bound (AI = 2.48 FLOP/byte
ridge point = 18 FLOP/byte). The bottleneck is DRAM bandwidth consumed by im2col data movement,
compounded by Python interpreter overhead. The proposed hardware accelerator changes this by
implementing im2col in hardware with on-chip weight caching, raising the effective arithmetic
intensity to approximately 10 FLOP/byte and moving the kernel into the compute-bound regime.
Fixed-point (INT8/INT16) arithmetic further reduces memory footprint by 4-8x relative to FP64,
enabling denser parallelism. The accelerator design therefore successfully transforms the bottleneck
from memory bandwidth to MAC throughput, which is the intended outcome for a fixed-function
convolution engine implemented in SystemVerilog.
