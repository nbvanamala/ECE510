# GEMM Analysis: Naive vs Tiled

## Results Summary
- Naive GEMM: 106.593 ms, 20.15 GFLOP/s
- Tiled GEMM:  29.052 ms, 73.92 GFLOP/s
- Speedup: 3.67x

## (a) Why the Naive Kernel is Memory-Bound
The naive kernel assigns one thread per output element C[i][j]. Each
thread independently loads a full row of A and a full column of B from
global DRAM with no data reuse between threads. For N=1024, this means
2×1024 DRAM reads per output element. The arithmetic intensity is far
below the ridge point of the T4 GPU (~27 FLOP/byte), placing the kernel
deep in the memory-bound region. Our measured result of 20.15 GFLOP/s,
compared to the T4 peak of 8100 GFLOP/s, confirms the kernel is
bottlenecked by DRAM bandwidth rather than compute throughput.

## (b) How Tiling Reduces DRAM Traffic
The tiled kernel uses shared memory to load T×T blocks of A and B once,
then reuses each loaded value T=8 times before fetching new data from
DRAM. This reduces total DRAM traffic by a factor of T, increasing
arithmetic intensity and moving the kernel higher on the roofline.
Shared memory is much faster than DRAM, so threads spend less time
waiting for data, which explains the significant speedup observed in
our measurements (29.052 ms vs 106.593 ms).

## (c) Whether Tiled Kernel Achieved Expected Improvement
The tiled kernel achieved 73.92 GFLOP/s — a 3.67× improvement over the
naive kernel's 20.15 GFLOP/s. While this is a clear improvement, it
falls short of the theoretical 8× reduction from T=8 tiling. Both
kernels remain memory-bound on the roofline plot, sitting left of the
ridge point. The remaining bottleneck is likely shared memory bank
conflicts and the relatively small tile size of T=8. Increasing the
tile size to T=16 or T=32 would further reduce DRAM traffic and push
the kernel closer to the compute-bound region.
