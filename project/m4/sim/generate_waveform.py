"""
generate_waveform.py — M4 Final
Generates final_waveform.png from final_waveform.vcd (produced by tb_top.sv).
Title: no "Systolic Array" — corrected to "Weight-Stationary Parallel PE Array".
"""
import re
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pathlib import Path

VCD_PATH = Path("C:/Users/navee/ECE510/project/m4/sim/final_waveform.vcd")
OUT_PATHS = [
    Path("C:/Users/navee/ECE510/project/m4/sim/final_waveform.png"),
    Path("C:/Users/navee/ECE510/project/m4/report/figures/final_waveform.png"),
]

# ---------------------------------------------------------------------------
# Minimal VCD parser (1-bit signals only)
# ---------------------------------------------------------------------------
def parse_vcd(path):
    signals = {}
    current_time = 0
    scope_stack  = []
    PS_PER_NS    = 1000

    with open(path, "r") as fh:
        lines = fh.read().splitlines()

    i = 0
    while i < len(lines):
        line = lines[i].strip()

        if line.startswith("$scope"):
            parts = line.split()
            if len(parts) >= 3:
                scope_stack.append(parts[2])

        elif line.startswith("$upscope"):
            if scope_stack:
                scope_stack.pop()

        elif line.startswith("$var"):
            parts = line.split()
            if len(parts) >= 5:
                sym  = parts[3]
                name = parts[4]
                full = ".".join(scope_stack + [name]) if scope_stack else name
                signals[sym] = {"name": full, "times": [], "vals": []}

        elif line.startswith("#"):
            try:
                current_time = int(line[1:])   # already in ps (timescale 1ns/1ps)
            except ValueError:
                pass

        elif len(line) == 2 and line[0] in "01xX":
            bit = 1 if line[0] == "1" else 0
            sym = line[1]
            if sym in signals:
                signals[sym]["times"].append(current_time)
                signals[sym]["vals"].append(bit)
        i += 1

    by_name = {}
    for info in signals.values():
        n = len(info["times"])
        if 0 < n < 200_000:
            by_name[info["name"]] = (
                np.array(info["times"], dtype=np.int64),
                np.array(info["vals"],  dtype=np.int64))
    return by_name


def get_sig(by_name, hint):
    for name, data in by_name.items():
        if name.endswith("." + hint) or name == hint:
            return data
    return (np.array([0], dtype=np.int64), np.array([0], dtype=np.int64))


def make_step(times, vals, t0, t1):
    if len(times) == 0:
        return np.array([t0, t1]), np.array([0, 0])
    idx = int(np.searchsorted(times, t0, side="right")) - 1
    iv  = int(vals[idx]) if idx >= 0 else 0
    ta  = np.concatenate([[t0], times, [t1]])
    va  = np.concatenate([[iv],  vals,  [int(vals[-1])]])
    m   = (ta >= t0) & (ta <= t1)
    return ta[m], va[m]


# ---------------------------------------------------------------------------
# Plot — show RUN 1 in detail (0 … 2000 ns), clean and annotated
# ---------------------------------------------------------------------------
def main():
    print(f"Parsing {VCD_PATH} ...")
    by_name = parse_vcd(VCD_PATH)
    print(f"  {len(by_name)} signals found")

    # ps units: 1 ps per unit (timescale 1ns/1ps → each #N means N ps)
    # Run 1 spans t=375 ns (measure start) to t=1886 ns (run 1 complete)
    # Show 0 … 2100 ns for a clean single-run view
    PS_NS   = 1000          # 1 ns = 1000 ps
    T0      = 0
    T1      = 2100 * PS_NS  # 2100 ns in ps

    sigs = [
        ("clk",         "clk"),
        ("rst",         "rst"),
        ("s_awvalid",   "s_awvalid"),
        ("s_awready",   "s_awready"),
        ("s_wvalid",    "s_wvalid"),
        ("s_wready",    "s_wready"),
        ("valid_out\n(→ PE)", "valid_out"),
        ("result_valid","result_valid"),
        ("reg_done",    "reg_done"),
        ("s_arvalid",   "s_arvalid"),
        ("s_arready",   "s_arready"),
        ("s_rvalid",    "s_rvalid"),
    ]

    COL = {
        "clk":          "#44475a",
        "rst":          "#ff5555",
        "s_awvalid":    "#50fa7b",
        "s_awready":    "#8be9fd",
        "s_wvalid":     "#ffb86c",
        "s_wready":     "#ff79c6",
        "valid_out\n(→ PE)": "#f1fa8c",
        "result_valid": "#50fa7b",
        "reg_done":     "#ff5555",
        "s_arvalid":    "#8be9fd",
        "s_arready":    "#50fa7b",
        "s_rvalid":     "#ffb86c",
    }

    n = len(sigs)
    fig, axes = plt.subplots(n, 1, figsize=(16, n * 0.72 + 2.2), sharex=True)
    fig.patch.set_facecolor("#1e1e2e")

    for ax, (label, hint) in zip(axes, sigs):
        ax.set_facecolor("#282a36")
        for sp in ax.spines.values():
            sp.set_color("#44475a")
        ax.tick_params(colors="#f8f8f2", labelsize=6)
        ax.set_ylabel(label, color="#f8f8f2", fontsize=7,
                      rotation=0, ha="right", va="center", labelpad=4)
        ax.set_yticks([])
        ax.set_ylim(-0.15, 1.35)
        ax.grid(axis="x", color="#44475a", linestyle="--", linewidth=0.4, alpha=0.5)

        t_arr, v_arr = get_sig(by_name, hint)
        ts, vs = make_step(t_arr, v_arr, T0, T1)
        t_ns   = ts / PS_NS
        col    = COL.get(label, "#f8f8f2")
        ax.step(t_ns, vs, where="post", color=col, linewidth=1.2)
        ax.fill_between(t_ns, 0, vs, step="post", alpha=0.22, color=col)

    # Region annotations (ns)
    regions = [
        (75,   375,  "Reset +\nWeight Load",       "#50fa7b"),
        (375,  1636, "Run 1: Pixel Stream\n(9 taps × PIXEL_IN + CTRL)", "#bd93f9"),
        (1636, 1886, "DONE poll +\n4 Result reads", "#ffb86c"),
        (1886, 2100, "Run 2\nstarts →",             "#f1fa8c"),
    ]
    for ax in axes:
        for x0, x1, _, col in regions:
            ax.axvspan(x0, x1, alpha=0.07, color=col, zorder=0)
    for x0, x1, lbl, col in regions:
        axes[0].text((x0 + x1) / 2, 1.18, lbl, ha="center", va="bottom",
                     fontsize=6.5, color=col,
                     bbox=dict(boxstyle="round,pad=0.2", fc="#1e1e2e",
                               ec=col, lw=0.8, alpha=0.9))

    axes[-1].set_xlabel("Simulation Time (ns)", color="#f8f8f2", fontsize=9)
    axes[-1].tick_params(axis="x", colors="#f8f8f2", labelsize=8)

    # Key timing marker
    axes[0].axvline(375, color="#f1fa8c", lw=1.0, linestyle="--", alpha=0.8)
    axes[0].text(377, 0.05, "t=375 ns\nmeasure\nstart", color="#f1fa8c",
                 fontsize=6, va="bottom")

    fig.suptitle(
        "M4 Final Co-simulation Waveform — Edge CNN Accelerator\n"
        "Weight-Stationary Parallel PE Array  |  AXI4-Lite  |  100 MHz  |  "
        "Icarus Verilog 12.0  |  3 invocations, 151 cycles/patch  |  PASS",
        color="#f8f8f2", fontsize=9, y=0.998)

    fig.text(0.5, 0.001,
             "Edge CNN Accelerator — Weight-Stationary Parallel PE Array  "
             "|  ECE510 Spring 2026  |  Naveen Babu Vanamala",
             ha="center", va="bottom", color="#aaaaaa", fontsize=7.5)

    plt.tight_layout(rect=[0.09, 0.015, 1, 0.96])

    for out in OUT_PATHS:
        plt.savefig(str(out), dpi=150, bbox_inches="tight",
                    facecolor="#1e1e2e", edgecolor="none")
        print(f"Saved: {out}")


if __name__ == "__main__":
    main()
