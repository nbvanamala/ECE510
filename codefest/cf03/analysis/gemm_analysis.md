# GEMM Analysis: Naive vs Tiled

## Results Summary

| Kernel     | Time (ms)     | GFLOP/s          | AI (FLOP/byte) | Achieved BW   | Bound  |
|------------|--------------|------------------|---------------|--------------|--------|
| gemm_naive | 6.560       | 327.36            | 0.25          | 1309.4 GB/s    | Memory |
| gemm_tiled | 4.925       | 436.01            | 2.00          | 218.0 GB/s   | Memory |

- **Speedup**: 1.33x
- **T4 ridge point**: ~27.1 FLOP/byte (8141 GFLOP/s peak compute / 300 GB/s peak BW)
- **Nsight Compute (ncu)**: see ncu_naive.txt and ncu_tiled.txt in this folder.
  Both kernels sit well left of the ridge point (AI 0.25 and 2.0 vs ridge 27.1),
  confirming memory-bound placement. Achieved DRAM bandwidth from ncu:
  naive 1309.4 GB/s, tiled 218.0 GB/s (peak 300 GB/s).

## (a) Why the Naive Kernel is Memory-Bound

The naive kernel assigns one thread per output element C[i][j]. Each thread
independently loads a full row of A and a full column of B directly from global
DRAM with no data sharing between threads. For N=1024, each output element
requires 2x1024 = 2048 DRAM reads, giving an arithmetic intensity of
2xN^3 FLOPs / (2xN^3x4 bytes) = 0.25 FLOP/byte — far below the T4 ridge point
of 27.1 FLOP/byte. Nsight Compute confirms this: achieved DRAM bandwidth is
1309.4 GB/s while SM compute utilization is negligible relative to peak.
The measured 327.36 GFLOP/s versus the 8141 GFLOP/s FP32 peak shows the
kernel is bottlenecked entirely by memory bandwidth, not compute.

## (b) How Tiling Reduces DRAM Traffic

The tiled kernel loads TxT (8x8) sub-blocks of A and B into on-chip shared
memory once per tile step, then each loaded value is reused T=8 times for the
inner product before the next DRAM fetch. This raises arithmetic intensity by a
factor of T: from 0.25 to T/4 = 2.0 FLOP/byte. Each matrix element is fetched
from DRAM only N/T = 128 times instead of N = 1024 times — an 8x reduction in
traffic. Nsight Compute measures 218.0 GB/s achieved bandwidth for the tiled
kernel versus 1309.4 GB/s for naive, confirming more efficient memory use and
explaining the 1.33x speedup (6.560 ms to 4.925 ms).

## (c) Whether Tiled Kernel Achieved Expected Improvement

The tiled kernel achieved 436.01 GFLOP/s, a 1.33x improvement over the
naive kernel's 327.36 GFLOP/s. This is less than the theoretical 8x from T=8
tiling. Both kernels remain memory-bound (AI 2.0 is still left of the 27.1
ridge point on the roofline). The main remaining bottleneck is shared memory
bank conflicts: the column-major access pattern on sB[k][threadIdx.x] causes
multiple threads to hit the same bank simultaneously, serializing reads. A
secondary factor is low occupancy from the small 8x8 thread block (64 threads
per block), leaving many SMs idle. Increasing tile size to T=16 or T=32 would
reduce DRAM traffic further and improve occupancy, pushing the kernel closer
to the ridge point.
