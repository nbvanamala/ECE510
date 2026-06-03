"""
generate_roofline_m4.py
Regenerates roofline_final.png with the M4 measured HW point (47.7 MFLOPs/s,
151 cycles/patch from final_run.log TIMING SUMMARY).
"""
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pathlib import Path

# ── Platform parameters ───────────────────────────────────────────────────────
sky_peak_gflops = 0.800   # 100 MHz × 4 PEs × 2 FLOPs/MAC
sky_bw_gbs      = 0.133   # effective AXI4-Lite BW
sky_ridge       = sky_peak_gflops / sky_bw_gbs   # ~6.0 FLOPs/byte

cpu_ridge       = 2.75
cpu_bw_gbs      = 51.2
cpu_peak_gflops = cpu_ridge * cpu_bw_gbs

# ── Kernel AI bounds ──────────────────────────────────────────────────────────
ai_lower = 2.48
ai_upper = 2.88

# ── Operating points (M4 MEASURED from final_run.log TIMING SUMMARY) ─────────
# 151 cycles/patch × 10 ns = 1510 ns; 900 patches × 1510 ns = 1.359 ms
# Throughput = 64800 FLOPs / 1.359 ms = 47.7 MFLOPs/s
hw_gflops      = 0.0477   # 47.7 MFLOPs/s — measured, cosim, 151 cycles/patch
sw_loop_gflops = 0.005909 # 5.91 MFLOPs/s — M1 Python loop

ai_vals = np.logspace(-1, 2, 400)

def roofline(ai, peak, bw):
    return np.minimum(peak, bw * ai)

fig, ax = plt.subplots(figsize=(9, 6))

# ── Sky130A roofline ──────────────────────────────────────────────────────────
ax.loglog(ai_vals, roofline(ai_vals, sky_peak_gflops, sky_bw_gbs),
          color="#1a6e3c", linewidth=2.2, label="sky130A (this design)")
ax.axhline(sky_peak_gflops, color="#1a6e3c", linestyle="--", linewidth=1.0, alpha=0.5)
ax.text(70, sky_peak_gflops * 1.12,
        f"sky130A compute\n{sky_peak_gflops*1000:.0f} MFLOPs/s (100 MHz, 4 PE)",
        color="#1a6e3c", fontsize=7.5, ha="right")
ax.plot(sky_ridge, sky_peak_gflops, "o", color="#1a6e3c", markersize=8, zorder=5)
ax.text(sky_ridge * 0.65, sky_peak_gflops * 0.70,
        f"ridge\n{sky_ridge:.1f} FLOPs/B", color="#1a6e3c", fontsize=7.5, ha="right")

# ── i7-1165G7 roofline ────────────────────────────────────────────────────────
ax.loglog(ai_vals, roofline(ai_vals, cpu_peak_gflops, cpu_bw_gbs),
          color="#1f4e79", linewidth=2.2, label="i7-1165G7 (M1 SW platform)")
ax.axhline(cpu_peak_gflops, color="#1f4e79", linestyle="--", linewidth=1.0, alpha=0.5)
ax.text(90, cpu_peak_gflops * 1.12,
        f"CPU compute ~{cpu_peak_gflops:.0f} GFLOPs/s",
        color="#1f4e79", fontsize=7.5, ha="right")
ax.plot(cpu_ridge, cpu_peak_gflops, "o", color="#1f4e79", markersize=8, zorder=5)
ax.text(cpu_ridge * 0.65, cpu_peak_gflops * 0.70,
        f"ridge\n{cpu_ridge} FLOPs/B", color="#1f4e79", fontsize=7.5, ha="right")

# ── AI range shading ──────────────────────────────────────────────────────────
ax.axvspan(ai_lower, ai_upper, alpha=0.12, color="gray", zorder=1)
ax.axvline(ai_lower, color="gray", linewidth=1.0, linestyle=":", zorder=2)
ax.axvline(ai_upper, color="gray", linewidth=1.0, linestyle=":", zorder=2)
ax.text(ai_lower * 0.85, 2e-3, f"AI_lower\n{ai_lower}", ha="right",
        fontsize=7.5, color="gray")
ax.text(ai_upper * 1.05, 2e-3, f"AI_upper\n{ai_upper}", ha="left",
        fontsize=7.5, color="gray")

# ── M4 HW point (MEASURED: 47.7 MFLOPs/s, 151 cycles/patch) ─────────────────
ax.plot(ai_lower, hw_gflops, "D", color="#c0392b", markersize=11, zorder=10,
        label=f"M4 HW accel (measured cosim): {hw_gflops*1000:.1f} MFLOPs/s")
ax.annotate(
    f"M4 HW accel\n(measured cosim)\n151 cycles/patch\n{hw_gflops*1000:.1f} MFLOPs/s",
    xy=(ai_lower, hw_gflops),
    xytext=(ai_lower * 9, hw_gflops * 3.5),
    fontsize=8.5, color="#c0392b",
    arrowprops=dict(arrowstyle="->", color="#c0392b", lw=1.4))

# ── SW baseline point ─────────────────────────────────────────────────────────
ax.plot(ai_lower, sw_loop_gflops, "s", color="#7d3c98", markersize=9, zorder=10,
        label=f"SW baseline (M1 Python loop): {sw_loop_gflops*1000:.1f} MFLOPs/s")
ax.annotate(
    f"SW baseline\n(M1 Python loop)\n{sw_loop_gflops*1000:.1f} MFLOPs/s",
    xy=(ai_lower, sw_loop_gflops),
    xytext=(ai_lower * 9, sw_loop_gflops * 0.15),
    fontsize=8.5, color="#7d3c98",
    arrowprops=dict(arrowstyle="->", color="#7d3c98", lw=1.4))

# ── BW slope annotation ───────────────────────────────────────────────────────
mid_bw = np.sqrt(0.1 * sky_ridge)
ax.text(mid_bw, sky_bw_gbs * mid_bw * 0.4,
        f"BW ceiling\n{sky_bw_gbs*1000:.0f} MB/s\n(= {sky_bw_gbs*ai_lower*1000:.0f} MFLOPs/s\nat AI={ai_lower})",
        rotation=30, color="#1a6e3c", fontsize=7.5)

# ── Axes ──────────────────────────────────────────────────────────────────────
ax.set_xlabel("Arithmetic Intensity (FLOPs/byte)", fontsize=12)
ax.set_ylabel("Attainable Performance (GFLOPs/s)", fontsize=12)
ax.set_title(
    "Roofline Analysis — Edge CNN Accelerator (M4 Final)\n"
    "sky130A ASIC vs. i7-1165G7 SW Baseline  |  ECE510 Spring 2026",
    fontsize=11)
ax.set_xlim(0.1, 100)
ax.set_ylim(1e-4, 1e3)
ax.grid(True, which="both", alpha=0.25)
ax.legend(loc="upper left", fontsize=8.5, framealpha=0.9)

plt.tight_layout()

base = Path("C:/Users/navee/ECE510/project/m4")
for dest in [base / "bench" / "roofline_final.png",
             base / "report" / "figures" / "roofline_final.png"]:
    plt.savefig(str(dest), dpi=150, bbox_inches="tight")
    print(f"Saved: {dest}")

print(f"\nM4 measured HW point: {hw_gflops*1000:.1f} MFLOPs/s at AI={ai_lower}")
print(f"Speedup over SW: {hw_gflops/sw_loop_gflops:.2f}x")
print(f"Gap to BW ceiling: {(sky_bw_gbs*ai_lower)/hw_gflops:.1f}x below BW ceiling")
