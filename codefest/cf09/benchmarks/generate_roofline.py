"""
Roofline Plot — CF09 Task 9
Edge CNN Accelerator | ECE510 Spring 2026 | Naveen Babu Vanamala

Platforms:
  sky130A ASIC  — our synthesis target (100 MHz, 4 PEs, AXI4-Lite interface)
  i7-1165G7     — M1 SW baseline platform (LPDDR4x 51.2 GB/s)

Accelerator operating point from M3 cosim (measured):
  Throughput: 60.0 MFLOPs/s = 0.060 GFLOPs/s
  AI: 2.48 FLOPs/byte (lower bound, no weight reuse)
      2.88 FLOPs/byte (upper bound, full weight reuse, weight-stationary)
"""

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.lines import Line2D

# ── Platform parameters ───────────────────────────────────────────────────────
# Sky130A ASIC (our design)
sky_peak_gflops  = 0.800   # 100 MHz × 4 PEs × 2 FLOPs/MAC
sky_bw_gbs       = 0.133   # effective AXI4-Lite BW: 1 write per 3 cycles × 4 B × 100 MHz
sky_ridge        = sky_peak_gflops / sky_bw_gbs  # ~6.0 FLOPs/byte

# i7-1165G7 platform (M1 SW baseline)
cpu_ridge        = 2.75    # from M1 sw_baseline.md (AI < ridge = memory-bound)
cpu_bw_gbs       = 51.2    # LPDDR4x, from M1 sw_baseline.md
cpu_peak_gflops  = cpu_ridge * cpu_bw_gbs  # ~140.8 GFLOPs/s

# ── Kernel AI bounds (from CF02 / CF09 CMAN hand calc) ───────────────────────
ai_lower = 2.48   # no weight reuse (lower bound, CF02)
ai_upper = 2.88   # full weight reuse, weight-stationary (upper bound)

# ── Operating points ──────────────────────────────────────────────────────────
hw_gflops    = 0.060    # measured from M3 cosim (120 cycles/patch, 100 MHz)
sw_loop_gflops = 0.005909  # M1-style Python loop baseline (CF09 Task 6 re-run)

# ── AI axis range ─────────────────────────────────────────────────────────────
ai_vals = np.logspace(-1, 2, 400)

def roofline(ai, peak_gflops, bw_gbs):
    return np.minimum(peak_gflops, bw_gbs * ai)

# ── Figure setup ──────────────────────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(9, 6))

# ── Sky130A roofline ──────────────────────────────────────────────────────────
y_sky = roofline(ai_vals, sky_peak_gflops, sky_bw_gbs)
ax.loglog(ai_vals, y_sky, color="#1a6e3c", linewidth=2.2, label=f"sky130A (this design)")

# BW ceiling annotation
ax.axhline(sky_peak_gflops, color="#1a6e3c", linestyle="--", linewidth=1.0, alpha=0.5)
ax.text(70, sky_peak_gflops * 1.12,
        f"sky130A compute\n{sky_peak_gflops*1000:.0f} MFLOPs/s (100 MHz, 4 PE)",
        color="#1a6e3c", fontsize=7.5, ha="right")

# Ridge point
ax.plot(sky_ridge, sky_peak_gflops, "o", color="#1a6e3c", markersize=8, zorder=5)
ax.text(sky_ridge * 0.65, sky_peak_gflops * 0.70,
        f"ridge\n{sky_ridge:.1f} FLOPs/B", color="#1a6e3c", fontsize=7.5, ha="right")

# ── i7-1165G7 roofline (M1 SW baseline platform) ─────────────────────────────
y_cpu = roofline(ai_vals, cpu_peak_gflops, cpu_bw_gbs)
ax.loglog(ai_vals, y_cpu, color="#1f4e79", linewidth=2.2, linestyle="-",
          label=f"i7-1165G7 (M1 SW platform)")
ax.axhline(cpu_peak_gflops, color="#1f4e79", linestyle="--", linewidth=1.0, alpha=0.5)
ax.text(90, cpu_peak_gflops * 1.12,
        f"CPU compute ~{cpu_peak_gflops:.0f} GFLOPs/s",
        color="#1f4e79", fontsize=7.5, ha="right")
ax.plot(cpu_ridge, cpu_peak_gflops, "o", color="#1f4e79", markersize=8, zorder=5)
ax.text(cpu_ridge * 0.65, cpu_peak_gflops * 0.70,
        f"ridge\n{cpu_ridge} FLOPs/B", color="#1f4e79", fontsize=7.5, ha="right")

# ── AI range span (lower and upper bounds) ────────────────────────────────────
ax.axvspan(ai_lower, ai_upper, alpha=0.12, color="gray", zorder=1)
ax.axvline(ai_lower, color="gray", linewidth=1.0, linestyle=":", zorder=2)
ax.axvline(ai_upper, color="gray", linewidth=1.0, linestyle=":", zorder=2)
ax.text(ai_lower * 0.85, 2e-3, f"AI_lower\n{ai_lower}", ha="right",
        fontsize=7.5, color="gray")
ax.text(ai_upper * 1.05, 2e-3, f"AI_upper\n{ai_upper}", ha="left",
        fontsize=7.5, color="gray")

# ── HW accelerator point (measured from cosim) ───────────────────────────────
ax.plot(ai_lower, hw_gflops, "D", color="#c0392b", markersize=10, zorder=10,
        label=f"HW accel (measured, cosim): {hw_gflops*1000:.0f} MFLOPs/s")
ax.annotate(f"HW accel\n(measured cosim)\n{hw_gflops*1000:.0f} MFLOPs/s",
            xy=(ai_lower, hw_gflops),
            xytext=(ai_lower * 8, hw_gflops * 2.5),
            fontsize=8.5, color="#c0392b",
            arrowprops=dict(arrowstyle="->", color="#c0392b", lw=1.3))

# ── SW baseline point (M1-style Python loop) ─────────────────────────────────
ax.plot(ai_lower, sw_loop_gflops, "s", color="#7d3c98", markersize=9, zorder=10,
        label=f"SW baseline (M1-loop): {sw_loop_gflops*1000:.1f} MFLOPs/s")
ax.annotate(f"SW baseline\n(M1 Python loop)\n{sw_loop_gflops*1000:.1f} MFLOPs/s",
            xy=(ai_lower, sw_loop_gflops),
            xytext=(ai_lower * 8, sw_loop_gflops * 0.15),
            fontsize=8.5, color="#7d3c98",
            arrowprops=dict(arrowstyle="->", color="#7d3c98", lw=1.3))

# ── Axes formatting ───────────────────────────────────────────────────────────
ax.set_xlabel("Arithmetic Intensity (FLOPs/byte)", fontsize=12)
ax.set_ylabel("Attainable Performance (GFLOPs/s)", fontsize=12)
ax.set_title("Roofline Analysis — Edge CNN Accelerator\n"
             "sky130A ASIC vs. i7-1165G7 SW Baseline  |  ECE510 CF09", fontsize=11)
ax.set_xlim(0.1, 100)
ax.set_ylim(1e-4, 1e3)
ax.grid(True, which="both", alpha=0.25)

# Annotate memory-bound region for sky130
mid_bw = np.sqrt(0.1 * sky_ridge)
ax.text(mid_bw, sky_bw_gbs * mid_bw * 0.4,
        f"BW ceiling\nslope = {sky_bw_gbs*1000:.0f} MB/s",
        rotation=30, color="#1a6e3c", fontsize=7.5)

ax.legend(loc="upper left", fontsize=8.5, framealpha=0.9)

plt.tight_layout()
out_path = "roofline_plot.png"
plt.savefig(out_path, dpi=150, bbox_inches="tight")
print(f"Saved: {out_path}")

# Print summary
print(f"\nKey numbers:")
print(f"  sky130A ridge point : {sky_ridge:.1f} FLOPs/byte")
print(f"  i7-1165G7 ridge pt  : {cpu_ridge:.2f} FLOPs/byte")
print(f"  Kernel AI lower     : {ai_lower} FLOPs/byte")
print(f"  Kernel AI upper     : {ai_upper} FLOPs/byte")
print(f"  HW throughput (sim) : {hw_gflops*1000:.1f} MFLOPs/s")
print(f"  SW throughput (loop): {sw_loop_gflops*1000:.3f} MFLOPs/s")
print(f"  Speedup HW/SW       : {hw_gflops/sw_loop_gflops:.1f}x")
print(f"\nBound analysis (sky130 roofline @ AI={ai_lower}):")
bw_ceiling_at_ai = sky_bw_gbs * ai_lower
print(f"  BW ceiling at kernel AI : {bw_ceiling_at_ai*1000:.1f} MFLOPs/s")
print(f"  Compute ceiling         : {sky_peak_gflops*1000:.0f} MFLOPs/s")
print(f"  HW actual               : {hw_gflops*1000:.1f} MFLOPs/s")
print(f"  Gap to BW ceiling       : {bw_ceiling_at_ai/hw_gflops:.1f}x below BW ceiling")
print(f"  => Design is NEITHER BW-bound NOR compute-bound:")
print(f"     AXI transaction overhead limits efficiency.")
