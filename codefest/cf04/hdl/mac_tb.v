// ============================================================
// mac_tb.v — Verilog Testbench for mac module
// Codefest 4 — CLLM Task 3
// Sequence:
//   1. [a=3,  b=4]  x3 cycles  → expect out: 12, 24, 36
//   2. Assert rst               → expect out: 0
//   3. [a=-5, b=2]  x2 cycles  → expect out: -10, -20
// ============================================================
`timescale 1ns/1ps

module mac_tb;

    // DUT signals
    logic              clk;
    logic              rst;
    logic signed [7:0]  a;
    logic signed [7:0]  b;
    logic signed [31:0] out;

    // Instantiate DUT (point at mac_correct.v for final simulation)
    mac dut (
        .clk (clk),
        .rst (rst),
        .a   (a),
        .b   (b),
        .out (out)
    );

    // 10 ns clock
    initial clk = 0;
    always #5 clk = ~clk;

    // Convenience task
    task check(input signed [31:0] expected, input string label);
        if (out !== expected)
            $display("FAIL  %s: got %0d, expected %0d", label, $signed(out), $signed(expected));
        else
            $display("PASS  %s: out = %0d", label, $signed(out));
    endtask

    initial begin
        // --- Reset ---
        rst = 1; a = 0; b = 0;
        @(posedge clk); #1;

        // --- Phase 1: a=3, b=4 for 3 cycles ---
        rst = 0; a = 3; b = 4;
        @(posedge clk); #1; check(32'sd12,  "Cycle 1 (a=3,b=4)");
        @(posedge clk); #1; check(32'sd24,  "Cycle 2 (a=3,b=4)");
        @(posedge clk); #1; check(32'sd36,  "Cycle 3 (a=3,b=4)");

        // --- Phase 2: assert reset ---
        rst = 1; a = 0; b = 0;
        @(posedge clk); #1; check(32'sd0, "After rst");

        // --- Phase 3: a=-5, b=2 for 2 cycles ---
        rst = 0; a = -5; b = 2;
        @(posedge clk); #1; check(-32'sd10, "Cycle 4 (a=-5,b=2)");
        @(posedge clk); #1; check(-32'sd20, "Cycle 5 (a=-5,b=2)");

        $display("--- Simulation complete ---");
        $finish;
    end

endmodule
