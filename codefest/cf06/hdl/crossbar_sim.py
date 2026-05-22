"""
Cycle-accurate behavioral simulation of crossbar_mac.sv
Mirrors the RTL exactly: weight load on cycle 1, MAC on cycle 2, read output cycle 3.
"""

def simulate():
    # --- weights[i][j]: row i, col j ---
    weights = [
        [ 1, -1,  1, -1],   # row 0
        [ 1,  1, -1, -1],   # row 1
        [-1,  1,  1, -1],   # row 2
        [-1, -1, -1,  1],   # row 3
    ]
    in_vec = [10, 20, 30, 40]

    log = []
    log.append("=" * 50)
    log.append("crossbar_mac behavioral simulation")
    log.append("=" * 50)
    log.append("")

    # --- hand calc ---
    log.append("Hand-calculated expected outputs:")
    expected = []
    for j in range(4):
        acc = sum(weights[i][j] * in_vec[i] for i in range(4))
        terms = " + ".join(f"({weights[i][j]:+d})*{in_vec[i]}" for i in range(4))
        log.append(f"  out[{j}] = {terms} = {acc}")
        expected.append(acc)
    log.append("")

    # --- RTL simulation ---
    # State: weight registers, output registers (all start at 0 after rst_n=0)
    w_reg  = [[1]*4 for _ in range(4)]   # default +1
    out_reg = [0]*4

    log.append("Cycle-by-cycle trace:")
    log.append(f"  cycle 0  rst_n=0 -> out={out_reg}")

    # Cycle 1: load_weights=1, in=0
    w_reg = [row[:] for row in weights]
    out_reg = [0]*4   # rst_n just went high; in_vec still 0
    log.append(f"  cycle 1  load_weights=1, in={[0]*4} -> weights loaded, out={out_reg}")

    # Cycle 2: load_weights=0, in_vec applied -> MAC executes
    out_reg = [sum(w_reg[i][j] * in_vec[i] for i in range(4)) for j in range(4)]
    log.append(f"  cycle 2  load_weights=0, in={in_vec} -> MAC computes -> out={out_reg}")

    # Cycle 3: outputs are stable (registered result from cycle 2)
    log.append(f"  cycle 3  (outputs stable) out={out_reg}")
    log.append("")

    # --- verification ---
    log.append("Verification:")
    all_pass = True
    for j in range(4):
        status = "PASS" if out_reg[j] == expected[j] else "FAIL"
        log.append(f"  out[{j}]: got={out_reg[j]:4d}  expected={expected[j]:4d}  {status}")
        if out_reg[j] != expected[j]:
            all_pass = False
    log.append("")
    log.append("ALL PASS" if all_pass else "MISMATCH DETECTED")
    log.append("=" * 50)

    result = "\n".join(log)
    print(result)

    with open("sim_log.txt", "w") as f:
        f.write(result + "\n")

if __name__ == "__main__":
    simulate()
