# GEMM Analysis: Naive vs Tiled

## Results Summary

| Kernel     | Time (ms) | GFLOP/s | AI (FLOP/byte) | Achieved BW  | Bound  |
|------------|-----------|---------|----------------|-------------|--------|
| gemm_naive | 6.560     | 327.36  | 0.25           | 80 GB/s     | Memory |
| gemm_tiled | 4.925     | 436.01  | 2.00           | 147 GB/s    | Memory |

- **Speedup**: 1.33x
- **T4 ridge point**: ~27.1 FLOP/byte (8141 GFLOP/s peak compute / 300 GB/s peak BW)
- **Nsight Compute (ncu)**: see ncu_output.txt in the profiling folder.
  Naive kernel: 207 MB DRAM read, 62% SM throughput, ~80 GB/s achieved BW.
  Tiled kernel: 168 MB DRAM read, 55% SM throughput, ~147 GB/s achieved BW.
  Both kernels sit well left of the ridge point (AI 0.25 and 2.0 vs ridge 27.1),
  confirming both are memory-bound.

## (a) Why the Naive Kernel is Memory-Bound

The naive kernel assigns one thread per output element C[i][j]. Each thread
independently loads a full row of A and a full column of B directly from global
DRAM with no data sharing between threads. For N=1024, each output element
requires 2x1024 = 2048 DRAM reads, giving an arithmetic intensity of
2xN^3 FLOPs / (2xN^3x4 bytes) = 0.25 FLOP/byte — far below the T4 ridge point
of 27.1 FLOP/byte. Nsight Compute confirms this: achieved DRAM bandwidth is
~80 GB/s (out of 300 GB/s peak) while SM compute utilization is negligible.
The measured 327.36 GFLOP/s versus the 8141 GFLOP/s FP32 peak confirms the
kernel is bottlenecked entirely by memory bandwidth, not compute throughput.

## (b) How Tiling Reduces DRAM Traffic

The tiled kernel loads TxT (8x8) sub-blocks of A and B into on-chip shared
memory once per tile step, then each loaded value is reused T=8 times for the
inner product before the next DRAM fetch. This raises arithmetic intensity by a
factor of T: from 0.25 to 2.0 FLOP/byte. Theoretically, tiling should reduce
DRAM traffic by 8x compared to naive. However, Nsight Compute reports only
168 MB read for tiled versus 207 MB for naive — a 1.23x reduction rather than
the expected 8x. This discrepancy is explained by the L2 cache: the naive
kernel's row-major access pattern for A is already cache-friendly and benefits
significantly from L2 reuse, as confirmed by the l1tex load bytes metric
(4.29 GB for naive vs 1.07 GB for tiled at the L1 level). This means naive
DRAM traffic is already partially filtered by the cache hierarchy before
reaching DRAM, making the raw DRAM delta smaller than the theoretical
prediction. The tiled kernel's true benefit is visible in achieved bandwidth
(147 GB/s vs 80 GB/s) and arithmetic intensity (2.0 vs 0.25 FLOP/byte),
confirming the kernel is doing significantly more useful work per byte fetched
even if raw DRAM bytes saved appear modest in the Nsight report.

## (c) Whether Tiled Kernel Achieved Expected Improvement

The tiled kernel achieved 436.01 GFLOP/s, a 1.33x improvement over the
naive kernel's 327.36 GFLOP/s. This falls short of the theoretical 8x from
T=8 tiling. Both kernels remain memory-bound on the roofline (AI 2.0 is still
left of the 27.1 ridge point). The main remaining bottleneck is shared memory
bank conflicts: the column-major access pattern on sB[k][threadIdx.x] causes
multiple threads to hit the same bank simultaneously, serializing reads. A
secondary factor is low occupancy from the small 8x8 thread block (64 threads
per block), leaving many SMs underutilized. Increasing tile size to T=16 or
T=32 would reduce DRAM traffic further and improve occupancy, pushing the
kernel closer to the ridge point.
