# Arithmetic Intensity Calculation — Edge CNN Accelerator

## Dominant Kernel: Conv2D._im2col (forward pass convolution)

### Parameters (synthetic dataset, representative layer)
- Batch size:     N     = 1
- Input channels: C_in  = 3
- Kernel size:    k     = 3
- Input spatial:  H = W = 32  →  H_out = W_out = 32 - 3 + 1 = 30
- Output channels: C_out = 16
- Precision:      FP64 (8 bytes per element)

---

## FLOPs Calculation

Formula for one forward pass through a Conv2D layer:

    FLOPs = 2 × N × C_in × k² × H_out × W_out × C_out

Substituting values:

    FLOPs = 2 × 1 × 3 × (3²) × 30 × 30 × 16
          = 2 × 1 × 3 × 9 × 30 × 30 × 16
          = 2 × 388,800
          = 777,600 FLOPs  ≈  7.78 × 10⁵ FLOPs

The factor of 2 counts one multiply-accumulate (MAC) = 1 multiply + 1 add.

---

## Bytes Transferred Calculation (No Cache Reuse Assumed)

### Input patch (im2col output matrix)
    Size = N × C_in × k² × H_out × W_out × 8 bytes
         = 1 × 3 × 9 × 30 × 30 × 8
         = 194,400 bytes

### Weight tensor
    Size = C_out × C_in × k² × 8 bytes
         = 16 × 3 × 9 × 8
         = 3,456 bytes

### Output activation
    Size = N × C_out × H_out × W_out × 8 bytes
         = 1 × 16 × 30 × 30 × 8
         = 115,200 bytes

### Total bytes transferred
    Bytes = 194,400 + 3,456 + 115,200
          = 313,056 bytes  ≈  3.13 × 10⁵ bytes

---

## Arithmetic Intensity

    AI = FLOPs / Bytes
       = 777,600 / 313,056
       ≈ 2.48 FLOP/byte

---

## Summary Table

| Quantity              | Value              |
|-----------------------|--------------------|
| FLOPs                 | 7.78 × 10⁵         |
| Bytes transferred     | 3.13 × 10⁵ bytes   |
| Arithmetic intensity  | 2.48 FLOP/byte     |
| Ridge point (Apple M2 FP64) | 18 FLOP/byte |
| Bound classification  | Memory-bound       |

### Hardware Reference: Apple M2 (laptop platform)
- Peak compute (FP64): ~1,800 GFLOP/s
- Peak memory bandwidth: ~100 GB/s
- Ridge point = 1,800 / 100 = 18 FLOP/byte

Since AI = 2.48 << ridge point = 18, the Conv2D kernel is **deeply memory-bound** on this hardware.
