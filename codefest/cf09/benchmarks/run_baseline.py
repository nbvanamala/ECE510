"""
SW Baseline Re-run — CF09 Task 6
Edge CNN Accelerator | ECE510 Spring 2026 | Naveen Babu Vanamala

Two implementations:
  (A) loop_im2col: Python loops over output positions, matching M1 cnn_backprop style
  (B) numpy_gemm : vectorized NumPy im2col+GEMM (optimized reference)

Hardware kernel configuration:
  - Kernel size:     3x3 (K2 = 9), matching KERNEL_SIZE=9 in hardware
  - Output channels: C_out = 4, matching NUM_PE=4
  - Input channels:  C_in  = 1 (single-channel broadcast, matching hardware)
  - Input spatial:   32x32 image
  - Precision:       INT8 inputs, int32 accumulation
"""

import time
import tracemalloc
import sys
import numpy as np

# ── Kernel configuration ─────────────────────────────────────────────────────
K        = 3
K2       = K * K           # 9
C_out    = 4               # matches NUM_PE
C_in     = 1
H = W    = 32
H_out    = H - K + 1       # 30
W_out    = W - K + 1       # 30
N_PATCH  = H_out * W_out   # 900 invocations per image

np.random.seed(42)
x = np.random.randint(-128, 127, (H, W), dtype=np.int8)
w = np.random.randint(-128, 127, (C_out, K, K), dtype=np.int8)

FLOPS_PER_IMAGE = K2 * C_in * C_out * 2 * N_PATCH  # 72 FLOPs/patch × 900 = 64,800

# ── (A) Loop-based im2col (mirrors M1 cnn_backprop nested-loop style) ────────
def conv_loop(x, w):
    """Python loops over output positions — slow, matches M1 baseline style."""
    out = np.zeros((H_out, W_out, C_out), dtype=np.int32)
    for i in range(H_out):
        for j in range(W_out):
            patch = x[i:i+K, j:j+K].astype(np.int32)  # (K, K)
            for c in range(C_out):
                out[i, j, c] = int(np.sum(patch * w[c].astype(np.int32)))
    return out

# ── (B) Vectorized NumPy im2col+GEMM ─────────────────────────────────────────
def conv_numpy(x, w):
    """Vectorized sliding-window im2col, matches library performance."""
    patches = np.lib.stride_tricks.sliding_window_view(x, (K, K))
    patches = patches.reshape(N_PATCH, K2).astype(np.int32)
    wmat    = w.reshape(C_out, K2).astype(np.int32)
    return (patches @ wmat.T).reshape(H_out, W_out, C_out)

def bench(fn, reps):
    for _ in range(3): fn(x, w)   # warm-up
    t0 = time.perf_counter()
    for _ in range(reps): fn(x, w)
    t1 = time.perf_counter()
    return (t1 - t0) / reps

def peak_mem(fn):
    tracemalloc.start()
    fn(x, w)
    _, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    return peak

# ── Run benchmarks ────────────────────────────────────────────────────────────
print("Benchmarking loop implementation (M1 style)…")
t_loop = bench(conv_loop, reps=20)
mem_loop = peak_mem(conv_loop)

print("Benchmarking NumPy GEMM implementation…")
t_numpy = bench(conv_numpy, reps=5000)
mem_numpy = peak_mem(conv_numpy)

# ── Report ────────────────────────────────────────────────────────────────────
def fmt(t_s, mem_bytes):
    gflops = FLOPS_PER_IMAGE / t_s / 1e9
    sps    = 1.0 / t_s
    return t_s*1e3, sps, gflops*1e3, mem_bytes/1024

loop_ms, loop_sps, loop_mflops, loop_mem_kb = fmt(t_loop, mem_loop)
np_ms, np_sps, np_mflops, np_mem_kb         = fmt(t_numpy, mem_numpy)

print()
print("=" * 62)
print("SW Baseline Re-run Results  (CF09 Task 6)")
print("=" * 62)
print(f"Platform : Python {sys.version.split()[0]}, NumPy {np.__version__}")
print(f"Kernel   : INT8 3x3 Conv, C_in={C_in}, C_out={C_out}, {H}x{W}")
print(f"FLOPs/img: {FLOPS_PER_IMAGE:,}  ({N_PATCH} patches × {FLOPS_PER_IMAGE//N_PATCH} FLOPs)")
print()
print(f"{'Method':<18} {'Time(ms)':<12} {'Img/s':<12} {'MFLOPs/s':<12} {'Mem(KB)':<10}")
print("-" * 62)
print(f"{'(A) Loop (M1-style)':<18} {loop_ms:<12.3f} {loop_sps:<12.1f} {loop_mflops:<12.3f} {loop_mem_kb:<10.1f}")
print(f"{'(B) NumPy GEMM':<18} {np_ms:<12.4f} {np_sps:<12.1f} {np_mflops:<12.3f} {np_mem_kb:<10.1f}")
print()
print("For benchmark_results.md (M1-style loop, matches original baseline):")
print(f"  exec_time = {loop_ms:.3f} ms per 32x32 image")
print(f"  throughput = {loop_mflops:.2f} MFLOPs/s")
print(f"  samples/sec = {loop_sps:.1f} img/s")
print(f"  memory = {loop_mem_kb:.1f} KB")
print()
print("Hardware accelerator (from M3 cosim at 100 MHz):")
print("  exec_time  = 1.08 ms per 32x32 image (900 patches × 1200 ns/patch)")
print("  throughput = 60.0 MFLOPs/s  (60 MFLOPs/s = 64800 FLOPs / 1.08 ms)")
print("  latency    = 1200 ns per patch invocation (120 cycles at 10 ns)")
print()
hw_mflops = 60.0
sw_mflops = loop_mflops
speedup = hw_mflops / sw_mflops
print(f"Speedup HW vs M1-loop = {speedup:.2f}x  (>1 means HW faster)")
print("=" * 62)
