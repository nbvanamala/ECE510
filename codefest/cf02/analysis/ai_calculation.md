# Arithmetic Intensity Calculation — Dominant Kernel
## ECE510 Codefest 2 | Naveen Babu Vanamala | Spring 2026

## Dominant Kernel: Conv2D._im2col → Convolution Forward Pass
Profiler identified Conv2D._im2col as dominant kernel: 80.6% of total runtime.

## CNN Layer Parameters
- Batch size N = 32
- Input channels C_in = 3
- Kernel size k = 3
- Input H, W = 32, 32
- Output channels C_out = 16
- Output H_out, W_out = 32, 32
- Data type: FP64 (8 bytes)

## FLOPs Calculation
FLOPs = 2 × N × C_in × k² × H_out × W_out × C_out
      = 2 × 32 × 3 × 9 × 32 × 32 × 16
      = 28,311,552 FLOPs ≈ 28.3 MFLOPs

## Bytes Transferred (no cache reuse)
Input patch  = 32 × 3 × 9 × 32 × 32 × 8 = 7,077,888 bytes
Weights      = 16 × 3 × 9 × 8            =     3,456 bytes
Output       = 32 × 16 × 32 × 32 × 8    = 4,194,304 bytes
Total        = 11,275,648 bytes ≈ 11.28 MB

## Arithmetic Intensity
AI = 28,311,552 / 11,275,648 = 2.51 FLOP/byte

## Hardware: Intel Core i7-1165G7
Peak compute  = 141 GFLOP/s
Peak BW       = 51.2 GB/s
Ridge point   = 141 / 51.2 = 2.75 FLOP/byte

## Bound Classification
Kernel AI (2.51) < Ridge point (2.75) → MEMORY-BOUND
Attainable performance = 2.51 × 51.2 = 128.5 GFLOP/s
