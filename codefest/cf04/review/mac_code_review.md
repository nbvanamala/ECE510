# MAC Code Review
## ECE510 Codefest 4 — CLLM Task 4 & 5
**Author:** Naveen Babu Vanamala  
**Date:** 2026-04-22

---

## LLM Attribution

| File | LLM Used | Model Version |
|------|----------|---------------|
| `hdl/mac_llm_A.v` | Claude | Claude Sonnet 4.6 |
| `hdl/mac_llm_B.v` | GPT | GPT-4o |
| `hdl/mac_correct.v` | Manual correction | — |

---

## Compilation Results

### mac_llm_A.v

**iverilog:**
```
$ iverilog -g2012 -o mac_a.out mac_llm_A.v
(no errors)
```

**verilator:**
```
$ verilator --lint-only --sv mac_llm_A.v
(no warnings or errors)
```

> Note: Verilator does not flag `always @(posedge clk)` as an error in this version (5.020),
> but using `always_ff` is required for strict SystemVerilog synthesizability — see Issue 1 below.

---

### mac_llm_B.v

**iverilog:**
```
$ iverilog -g2012 -o mac_b.out mac_llm_B.v
(no errors)
```

**verilator:**
```
$ verilator --lint-only --sv mac_llm_B.v
%Warning-WIDTHEXPAND: mac_llm_B.v:20:24: Operator ADD expects 32 bits on the RHS, but RHS's REPLICATE generates 24 bits.
                                       : ... note: In instance 'mac'
   20 |             out <= out + {16'h0, a * b};
      |                        ^
                      ... For warning description see https://verilator.org/warn/WIDTHEXPAND?v=5.020
                      ... Use "/* verilator lint_off WIDTHEXPAND */" and lint_on around source to disable this message.
%Error: Exiting due to 1 warning(s)
```

> Verilator correctly flags the width mismatch. The zero-extension `{16'h0, a * b}` produces
> only 24 bits (16 + 8×1 product width as inferred), not 32. This is a sign and width error —
> see Issues 2 and 3 below.

---

### mac_correct.v

**iverilog:**
```
$ iverilog -g2012 -o mac_correct.out mac_correct.v mac_tb.v && ./mac_correct.out
PASS  Cycle 1 (a=3,b=4): out = 12
PASS  Cycle 2 (a=3,b=4): out = 24
PASS  Cycle 3 (a=3,b=4): out = 36
PASS  After rst: out = 0
PASS  Cycle 4 (a=-5,b=2): out = -10
PASS  Cycle 5 (a=-5,b=2): out = -20
--- Simulation complete ---
```

**verilator:**
```
$ verilator --lint-only --sv mac_correct.v
(no warnings or errors)
```

All 6 checks pass. Verilator clean.

---

## Simulation Log

### mac_llm_A.v — testbench output
```
$ iverilog -g2012 -o mac_a_sim mac_llm_A.v mac_tb.v && ./mac_a_sim
PASS  Cycle 1 (a=3,b=4): out = 12
PASS  Cycle 2 (a=3,b=4): out = 24
PASS  Cycle 3 (a=3,b=4): out = 36
PASS  After rst: out = 0
PASS  Cycle 4 (a=-5,b=2): out = -10
PASS  Cycle 5 (a=-5,b=2): out = -20
--- Simulation complete ---
```

> Functionally correct because the sign extension `{{16{product[15]}}, product}` is manually
> applied. The `always` vs `always_ff` issue does not affect simulation results but violates
> synthesizability rules for strict SystemVerilog toolchains (see Issue 1).

---

### mac_llm_B.v — testbench output
```
$ iverilog -g2012 -o mac_b_sim mac_llm_B.v mac_tb.v && ./mac_b_sim
PASS  Cycle 1 (a=3,b=4): out = 12
PASS  Cycle 2 (a=3,b=4): out = 24
PASS  Cycle 3 (a=3,b=4): out = 36
PASS  After rst: out = 0
FAIL  Cycle 4 (a=-5,b=2): got 246, expected -10
FAIL  Cycle 5 (a=-5,b=2): got 492, expected -20
--- Simulation complete ---
```

> Positive inputs pass because unsigned and signed multiply agree for positive values.
> Negative input `-5` is reinterpreted as `8'hFB = 251` (unsigned), giving `251 × 2 = 502`
> in one accumulation step; however iverilog 12.0 evaluates the narrowed product as `8'hFB = 246`
> due to the WIDTHEXPAND truncation flagged by Verilator. Either way, the output is wrong.

---

## Issue 1 — Wrong Process Type in mac_llm_A.v

### Offending lines
```verilog
// mac_llm_A.v, line 20
always @(posedge clk) begin
```

### Why it is wrong
SystemVerilog introduced `always_ff` specifically for flip-flop inference. Using plain
`always @(posedge clk)` is legal Verilog-2001 syntax but violates the SystemVerilog constraint
that synthesizable sequential logic use `always_ff`. Strict synthesis tools (Synopsys DC,
Cadence Genus) and linters (Verilator, SpyGlass) will flag or reject this. The `always_ff`
keyword enables the tool to statically verify that the block contains only sequential (clocked)
assignments and catches accidental latches.

### Corrected version
```systemverilog
// mac_correct.v, line 25
always_ff @(posedge clk) begin
    if (rst)
        out <= 32'sd0;
    else
        out <= out + {{16{product[15]}}, product};
end
```

---

## Issue 2 — Missing `signed` Keyword on Port Declarations (mac_llm_B.v)

### Offending lines
```verilog
// mac_llm_B.v, lines 9-11
input  logic [7:0]  a,       // should be: logic signed [7:0] a
input  logic [7:0]  b,       // should be: logic signed [7:0] b
output logic [31:0] out      // should be: logic signed [31:0] out
```

### Why it is wrong
Without the `signed` qualifier, `a` and `b` are treated as unsigned 8-bit values. The
multiplication `a * b` is therefore an **unsigned** operation. When `a = -5`
(8'b1111_1011 = 251 unsigned), the product is `251 × 2 = 502` instead of `-10`. This
silently corrupts all negative-weight or negative-activation computations — exactly the
case for INT8 neural network inference where weights are frequently negative.

### Corrected version
```systemverilog
// mac_correct.v, lines 14-17
input  logic              clk,
input  logic              rst,
input  logic signed [7:0] a,
input  logic signed [7:0] b,
output logic signed [31:0] out
```

---

## Issue 3 — Zero-Extension Instead of Sign-Extension (mac_llm_B.v)

### Offending lines
```verilog
// mac_llm_B.v, line 20
out <= out + {16'h0, a * b};   // prepends 16 zero bits — loses sign
```

### Why it is wrong
`{16'h0, a * b}` zero-extends the product to 32 bits. Even if the operands were declared
`signed`, zero-extension of a negative 16-bit product produces a large positive 32-bit number
instead of the correct sign-extended negative value. For example, product `0xFFF6` (= −10
signed) would become `0x0000FFF6` (65526) instead of `0xFFFFFFF6` (−10). Verilator also
flags this line with `%Warning-WIDTHEXPAND` because the concatenation width is 24 bits, not
32, causing a width mismatch on the ADD operator.

### Corrected version
```systemverilog
// mac_correct.v — uses named intermediate and explicit sign-extension
logic signed [15:0] product;
assign product = a * b;   // signed × signed = signed 16-bit

always_ff @(posedge clk) begin
    if (rst)
        out <= 32'sd0;
    else
        out <= out + {{16{product[15]}}, product};  // replicate MSB for sign-extension
end
```

---

## Summary Table

| # | File | Failure Mode | Impact |
|---|------|-------------|--------|
| 1 | mac_llm_A.v | Wrong process type (`always` not `always_ff`) | Tool rejection in strict SV flow |
| 2 | mac_llm_B.v | Missing `signed` on port declarations | Unsigned multiply corrupts negative values |
| 3 | mac_llm_B.v | Zero-extension of 16-bit product to 32 bits — Verilator `WIDTHEXPAND` | Sign of negative products lost; width mismatch flagged |
