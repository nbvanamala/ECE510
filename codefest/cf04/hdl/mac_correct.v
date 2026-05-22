// ============================================================
// mac_correct.v
// Corrected INT8 MAC unit — synthesizable SystemVerilog
// Fixes from LLM A: uses always_ff (not plain always)
// Fixes from LLM B: signed port declarations + sign-extension
// ============================================================

module mac (
    input  logic              clk,
    input  logic              rst,          // Active-high synchronous reset
    input  logic signed [7:0] a,            // INT8 signed operand
    input  logic signed [7:0] b,            // INT8 signed operand
    output logic signed [31:0] out          // 32-bit signed accumulator
);

    // Intermediate 16-bit signed product; sign-extended to 32 bits on accumulation
    logic signed [15:0] product;
    assign product = a * b;

    always_ff @(posedge clk) begin
        if (rst)
            out <= 32'sd0;
        else
            out <= out + {{16{product[15]}}, product};  // Explicit sign-extension
    end

endmodule
