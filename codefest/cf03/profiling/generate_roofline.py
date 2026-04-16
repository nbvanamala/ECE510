"""
Roofline plot for gemm_naive and gemm_tiled on a T4 GPU.
Update MEASURED_* values with your actual ncu / cudaEvent output,
then re-run to regenerate gemm_roofline.png.
"""

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import os

# ── GPU hardware ceilings (T4 defaults; update if using a different GPU) ──────
PEAK_COMPUTE_GFLOPS = 8141.0    # FP32 TFLOP/s → GFLOP/s
PEAK_BW_GB_S        = 300.0     # DRAM bandwidth GB/s
RIDGE_POINT         = PEAK_COMPUTE_GFLOPS / PEAK_BW_GB_S  # ~27.1 FLOP/byte

# ── Measured kernel results (update with real ncu / cudaEvent numbers) ────────
# Arithmetic intensity = FLOPs / bytes_transferred
#   Naive  : 2*N^3 FLOPs / (8*N^3 bytes) = 0.25 FLOP/byte
#   Tiled  : 2*N^3 FLOPs / (8*N^3/T bytes) = T/4 = 2.0 FLOP/byte  (T=8)
NAIVE_AI_FLOP_BYTE   = 0.25
TILED_AI_FLOP_BYTE   = 2.0

# Replace these with the GFLOP/s printed by your kernels / ncu
NAIVE_PERF_GFLOPS    = 65.0     # placeholder
TILED_PERF_GFLOPS    = 420.0    # placeholder

# ── Plot ───────────────────────────────────────────────────────────────────────
ai = np.logspace(-2, 3, 500)
roof = np.minimum(PEAK_BW_GB_S * ai, PEAK_COMPUTE_GFLOPS)

fig, ax = plt.subplots(figsize=(8, 5))

ax.loglog(ai, roof, "k-", linewidth=2, label="Roofline (T4 GPU)")
ax.axvline(RIDGE_POINT, color="gray", linestyle="--", linewidth=1,
           label=f"Ridge point ({RIDGE_POINT:.1f} FLOP/byte)")

# Kernel operating points
ax.loglog(NAIVE_AI_FLOP_BYTE, NAIVE_PERF_GFLOPS, "rs", markersize=10,
          label=f"gemm_naive  ({NAIVE_PERF_GFLOPS:.0f} GFLOP/s)")
ax.loglog(TILED_AI_FLOP_BYTE, TILED_PERF_GFLOPS, "b^", markersize=10,
          label=f"gemm_tiled  ({TILED_PERF_GFLOPS:.0f} GFLOP/s)")

# Annotations
ax.annotate(f"naive\n{NAIVE_PERF_GFLOPS:.0f} GFLOP/s",
            xy=(NAIVE_AI_FLOP_BYTE, NAIVE_PERF_GFLOPS),
            xytext=(NAIVE_AI_FLOP_BYTE * 2.5, NAIVE_PERF_GFLOPS * 0.4),
            arrowprops=dict(arrowstyle="->", color="red"), color="red", fontsize=9)
ax.annotate(f"tiled\n{TILED_PERF_GFLOPS:.0f} GFLOP/s",
            xy=(TILED_AI_FLOP_BYTE, TILED_PERF_GFLOPS),
            xytext=(TILED_AI_FLOP_BYTE * 2.5, TILED_PERF_GFLOPS * 0.55),
            arrowprops=dict(arrowstyle="->", color="blue"), color="blue", fontsize=9)

# Ceiling labels
ax.axhline(PEAK_COMPUTE_GFLOPS, color="green", linestyle=":", linewidth=1)
ax.text(0.012, PEAK_COMPUTE_GFLOPS * 1.05,
        f"Peak compute: {PEAK_COMPUTE_GFLOPS:.0f} GFLOP/s",
        color="green", fontsize=8)
ax.text(RIDGE_POINT * 1.05, 5,
        f"Peak BW: {PEAK_BW_GB_S:.0f} GB/s",
        color="gray", fontsize=8, rotation=90, va="bottom")

ax.set_xlabel("Arithmetic Intensity (FLOP / byte)", fontsize=11)
ax.set_ylabel("Performance (GFLOP/s)", fontsize=11)
ax.set_title("Roofline Model — GEMM Naive vs. Tiled (N=1024, T4 GPU)", fontsize=12)
ax.legend(fontsize=9)
ax.grid(True, which="both", linestyle="--", alpha=0.4)
ax.set_xlim(0.01, 1000)
ax.set_ylim(1, PEAK_COMPUTE_GFLOPS * 2)

out_path = os.path.join(os.path.dirname(__file__), "gemm_roofline.png")
fig.tight_layout()
fig.savefig(out_path, dpi=150)
print(f"Saved: {out_path}")
