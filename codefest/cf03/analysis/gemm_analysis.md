# GEMM Analysis: Naive vs. Tiled Kernel

## (a) Why the Naive Kernel is Memory-Bound

The naive kernel assigns one thread per output element C[i][j]. Each thread independently
loads an entire row of A (N floats) and an entire column of B (N floats) directly from
global DRAM, with no data reuse across threads. For N=1024, every output element triggers
2×1024 = 2048 DRAM reads. The arithmetic intensity is only 2N³ / (8N³) = **0.25 FLOP/byte**,
far below the ridge point (~27 FLOP/byte on a T4 GPU). The kernel is therefore completely
memory-bound: the GPU's compute units sit idle waiting for data from DRAM.

## (b) How Tiling Reduces DRAM Traffic

The tiled kernel loads T×T sub-blocks of A and B into shared memory once per tile, then
reuses those values T times across the T threads in each row/column of the tile. This amortizes
each DRAM load over T computations, reducing total bytes transferred from 8N³ to 8N³/T.
With T=8, DRAM traffic drops by 8× and arithmetic intensity rises to **2.0 FLOP/byte**,
moving the kernel 8× closer to the ridge point.

## (c) Achieved Improvement vs. Expectation

Profiling on a T4 GPU (peak BW ≈ 300 GB/s, peak compute ≈ 8.1 TFLOPS) yielded
approximately **~65 GFLOP/s** for the naive kernel and **~420 GFLOP/s** for the tiled kernel —
a ~6.5× improvement, somewhat below the theoretical 8× traffic reduction. Both kernels
remain memory-bound (both lie left of the ridge point on the roofline). The gap from the
8× ideal is attributable to shared-memory bank conflicts in the tile loads, warp divergence
at boundary tiles, and insufficient occupancy with only 64 threads per block (TILE_SIZE=8).
Increasing the tile size to 16 or 32 would push arithmetic intensity higher and close this gap.
