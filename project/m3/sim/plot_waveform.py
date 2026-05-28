"""
plot_waveform.py — Generate annotated waveform PNG from cosim.vcd
Course  : ECE510 Spring 2026
Project : Edge CNN Accelerator, Milestone 3

Reads cosim.vcd (produced by iverilog/vvp) and renders:
  Region 1 — Host AXI write transactions (weight loads + pixel stream)
  Region 2 — Internal compute activity (valid_in, result_valid)
  Region 3 — Host AXI read of result register

Signals displayed:
  clk, rst, s_awvalid, s_awready, s_wvalid, s_wready,
  valid_from_intf, valid_in_r, result_valid_w, done_r,
  s_arvalid, s_arready, s_rvalid
"""

import re
import sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyArrowPatch

# ---------------------------------------------------------------------------
# Minimal VCD parser
# ---------------------------------------------------------------------------
MAX_TRANSITIONS = 200_000  # skip ultra-high-frequency signals (clock, loop vars)

def parse_vcd(path):
    """Return {net_name: [(time_ps, int_value), ...]} for 1-bit nets, plus timescale."""
    signals = {}     # symbol -> {"name": ..., "width": ..., "times": [], "vals": []}
    sym_map  = {}    # symbol -> name

    with open(path, "r") as fh:
        lines = fh.read().splitlines()

    timescale_mult = 1
    current_time   = 0
    in_dumpvars    = False
    scope_stack    = []

    i = 0
    while i < len(lines):
        line = lines[i].strip()
        # timescale
        if "$timescale" in line:
            ts = ""
            while "$end" not in lines[i]:
                ts += lines[i]
                i += 1
            ts += lines[i]
            m = re.search(r"(\d+)\s*(ps|ns|us|ms)", ts)
            if m:
                v, u = int(m.group(1)), m.group(2)
                timescale_mult = v * {"ps":1,"ns":1000,"us":1_000_000,"ms":1_000_000_000}[u]
        # scope
        if line.startswith("$scope"):
            parts = line.split()
            if len(parts) >= 3:
                scope_stack.append(parts[2])
        if line.startswith("$upscope"):
            if scope_stack:
                scope_stack.pop()
        # var
        if line.startswith("$var"):
            parts = line.split()
            # $var wire WIDTH SYMBOL NAME $end
            if len(parts) >= 5:
                width  = int(parts[2])
                sym    = parts[3]
                name   = parts[4]
                full   = ".".join(scope_stack + [name]) if scope_stack else name
                signals[sym]  = {"name": full, "width": width, "times": [], "vals": []}
                sym_map[full] = sym
        # time
        if line.startswith("#"):
            try:
                current_time = int(line[1:]) * timescale_mult
            except ValueError:
                pass
        # value changes
        if line.startswith("b"):
            parts = line.split()
            if len(parts) == 2:
                val_str, sym = parts[0][1:], parts[1]
                if sym in signals:
                    try:
                        val = int(val_str, 2)
                    except ValueError:
                        val = 0
                    signals[sym]["times"].append(current_time)
                    signals[sym]["vals"].append(val)
        elif len(line) == 2 and line[0] in "01xX":
            bit = 0 if line[0] in "0xX" else 1
            sym = line[1]
            if sym in signals:
                signals[sym]["times"].append(current_time)
                signals[sym]["vals"].append(bit)
        i += 1

    # Build lookup by full name; skip ultra-high-frequency signals
    by_name = {}
    for sym, info in signals.items():
        n_trans = len(info["times"])
        if n_trans > MAX_TRANSITIONS:
            continue  # skip clock / loop variables (millions of transitions)
        try:
            by_name[info["name"]] = (
                np.array(info["times"], dtype=np.int64),
                np.array(info["vals"],  dtype=np.int64))
        except OverflowError:
            clamped = [min(v, 1) for v in info["vals"]]
            by_name[info["name"]] = (
                np.array(info["times"], dtype=np.int64),
                np.array(clamped,       dtype=np.int64))
    return by_name, timescale_mult


def make_step(times, vals, t_start, t_end):
    """Convert (times, vals) to step-plot arrays clipped to [t_start, t_end]."""
    if len(times) == 0:
        return np.array([t_start, t_end]), np.array([0, 0])
    # Prepend initial value before t_start
    idx = np.searchsorted(times, t_start, side="right") - 1
    init_val = vals[idx] if idx >= 0 else 0
    t_all = np.concatenate([[t_start], times, [t_end]])
    v_all = np.concatenate([[init_val], vals, [vals[-1]]])
    # Clip
    mask = (t_all >= t_start) & (t_all <= t_end)
    t_c  = np.concatenate([[t_start], t_all[mask][1:]])
    v_c  = np.concatenate([[init_val], v_all[mask][1:]])
    return t_c, v_c


# ---------------------------------------------------------------------------
# Plot
# ---------------------------------------------------------------------------
def main():
    vcd_path = "cosim.vcd"
    out_path = "cosim_waveform.png"

    print(f"Parsing {vcd_path} ...")
    by_name, ts_mult = parse_vcd(vcd_path)

    # Show available signal names
    print("Available signals:")
    for n in sorted(by_name.keys()):
        t, v = by_name[n]
        if len(t) > 0:
            print(f"  {n}  ({len(t)} transitions)")

    # Signal name aliases (module hierarchy in iverilog VCD)
    def get(name_hint):
        """Try several naming conventions."""
        for n in by_name:
            if n.endswith("." + name_hint) or n == name_hint:
                return by_name[n]
        return (np.array([0]), np.array([0]))

    # Synthetic clock for display (100 MHz = 10 ns period)
    clk_ps = np.arange(T_START, T_END, 5000, dtype=np.int64)
    clk_v  = np.tile([0, 1], len(clk_ps) // 2 + 1)[:len(clk_ps)]
    by_name["__synthetic_clk__"] = (clk_ps, clk_v)

    # Focus on TEST 1 (first ~400 ns) so waveform is readable
    # Each AXI transaction ≈ 3 cycles × 10 ns = 30 ns
    # 4 weight loads + 9 pixel loads = 13 transactions × 2 AXI writes = 26 writes ≈ 780 ns
    # Plus STATUS polls + result read ≈ ~1200 ns total for test 1
    T_START = 0
    T_END   = 1_500_000   # 1500 ns in ps
    PS_PER_NS = 1000

    def ns(t_ps): return t_ps / PS_PER_NS

    # Signal hints: matches any VCD signal ending with ".HINT"
    # VCD uses full hierarchy: tb_top.dut.u_intf.u_slave.s_awvalid etc.
    sigs_to_plot = [
        ("clk",             "__synthetic_clk__"),
        ("rst",             "rst"),
        ("s_awvalid",       "s_awvalid"),
        ("s_awready",       "s_awready"),
        ("s_wvalid",        "s_wvalid"),
        ("s_wready",        "s_wready"),
        ("valid_from_intf", "valid_out"),       # interface's valid_out = valid_from_intf
        ("valid_in (PE0)",  "valid_in"),        # compute core's valid_in to PE
        ("result_valid",    "result_valid"),    # compute core result_valid output
        ("done_r",          "done_in"),         # interface's done_in port = top's done_r
        ("s_arvalid",       "s_arvalid"),
        ("s_arready",       "s_arready"),
        ("s_rvalid",        "s_rvalid"),
    ]

    n_rows = len(sigs_to_plot)
    fig, axes = plt.subplots(n_rows, 1, figsize=(18, n_rows * 0.7 + 1.5),
                              sharex=True)
    fig.patch.set_facecolor("#1e1e2e")

    colors = {
        "clk":            "#44475a",
        "rst":            "#ff5555",
        "s_awvalid":      "#50fa7b",
        "s_awready":      "#8be9fd",
        "s_wvalid":       "#ffb86c",
        "s_wready":       "#ff79c6",
        "valid_from_intf":"#f1fa8c",
        "valid_in_r":     "#bd93f9",
        "result_valid_w": "#50fa7b",
        "done_r":         "#ff5555",
        "s_arvalid":      "#8be9fd",
        "s_arready":      "#50fa7b",
        "s_rvalid":       "#ffb86c",
    }

    for ax, (label, sig_hint) in zip(axes, sigs_to_plot):
        ax.set_facecolor("#282a36")
        for spine in ax.spines.values():
            spine.set_color("#44475a")
        ax.tick_params(colors="#f8f8f2", labelsize=7)
        ax.set_ylabel(label, color="#f8f8f2", fontsize=7, rotation=0,
                      ha="right", va="center", labelpad=5)
        ax.set_yticks([])

        t_arr, v_arr = get(sig_hint)
        t_s, v_s = make_step(t_arr, v_arr, T_START, T_END)
        t_ns = t_s / PS_PER_NS
        col  = colors.get(label, "#f8f8f2")
        ax.step(t_ns, v_s, where="post", color=col, linewidth=1.2)
        ax.fill_between(t_ns, 0, v_s, step="post", alpha=0.25, color=col)
        ax.set_ylim(-0.15, 1.3)
        ax.grid(axis="x", color="#44475a", linestyle="--", linewidth=0.4, alpha=0.5)

    axes[-1].set_xlabel("Time (ns)", color="#f8f8f2", fontsize=9)
    axes[-1].tick_params(axis="x", colors="#f8f8f2", labelsize=8)

    # --- Annotate three regions ---
    # Estimate regions from protocol timing (approximate):
    #   Reset: 0-60 ns
    #   Weight loads (4×2 writes): ~60-540 ns
    #   Pixel stream (9×2 writes): ~540-1080 ns
    #   Wait + STATUS poll + result read: ~1080-1500 ns

    region_ax = axes[0]   # draw region boxes on top axes
    regions = [
        (60,  540,  "Region 1\nHost AXI writes\n(weight loads)",  "#50fa7b"),
        (540, 1080, "Region 2\nInternal compute\n(pixel stream)", "#bd93f9"),
        (1080,1500, "Region 3\nHost AXI read\n(STATUS + RESULT)", "#ffb86c"),
    ]
    for ax in axes:
        for x0, x1, lbl, col in regions:
            ax.axvspan(x0, x1, alpha=0.06, color=col, zorder=0)

    # Label only on the first axis
    for x0, x1, lbl, col in regions:
        axes[0].text((x0 + x1) / 2, 1.15, lbl, ha="center", va="bottom",
                     fontsize=7, color=col,
                     bbox=dict(boxstyle="round,pad=0.2", fc="#1e1e2e",
                               ec=col, lw=1, alpha=0.9))

    fig.suptitle(
        "M3 Co-simulation Waveform — Edge CNN Accelerator (cnn_top)\n"
        "Test: pixel=1, weight=1, KERNEL_SIZE=9 → result=9  |  Simulator: iverilog 12.0",
        color="#f8f8f2", fontsize=10, y=0.995)

    plt.tight_layout(rect=[0.08, 0, 1, 0.97])
    plt.savefig(out_path, dpi=150, bbox_inches="tight",
                facecolor="#1e1e2e", edgecolor="none")
    print(f"Waveform saved to {out_path}")


if __name__ == "__main__":
    main()
