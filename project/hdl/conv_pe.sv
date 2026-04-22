// ============================================================
// conv_pe.sv — Parameterized INT8 Convolution Processing Element
// Project: Edge CNN Accelerator (ECE510 Spring 2026)
// Interface: AXI4 (on-chip) — see project/m1/interface_selection.md
// Precision: INT8 (symmetric quantization per CF04 CMAN)
//
// This module implements one convolution PE that accumulates
// DATA_WIDTH-bit signed pixel * weight products over a
// KERNEL_SIZE-tap window (default 3×3 = 9 taps).
// A valid_out pulse marks the end of one output pixel.
// ============================================================

module conv_pe #(
    parameter int DATA_WIDTH   = 8,   // INT8 precision
    parameter int ACCUM_WIDTH  = 32,  // 32-bit accumulator (prevents overflow)
    parameter int KERNEL_SIZE  = 9    // 3×3 convolution = 9 MAC operations
) (
    input  logic                         clk,
    input  logic                         rst,        // Active-high synchronous reset

    // Data interface
    input  logic                         valid_in,   // Pixel/weight pair is valid
    input  logic signed [DATA_WIDTH-1:0] pixel_in,   // Input feature map pixel
    input  logic signed [DATA_WIDTH-1:0] weight_in,  // Kernel weight

    // Output interface
    output logic signed [ACCUM_WIDTH-1:0] accum_out, // Completed dot-product result
    output logic                          valid_out   // High for one cycle when done
);

    // ---------------------------------------------------------
    // Internal signals
    // ---------------------------------------------------------
    logic signed [ACCUM_WIDTH-1:0]      accum_reg;
    logic signed [2*DATA_WIDTH-1:0]     product;
    logic [$clog2(KERNEL_SIZE+1)-1:0]   tap_count;

    assign product = pixel_in * weight_in;   // Signed 16-bit product

    // ---------------------------------------------------------
    // Accumulation FSM
    // ---------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            accum_reg  <= '0;
            accum_out  <= '0;
            tap_count  <= '0;
            valid_out  <= 1'b0;
        end else begin
            valid_out <= 1'b0;   // Default: no output this cycle

            if (valid_in) begin
                accum_reg <= accum_reg + {{(ACCUM_WIDTH-2*DATA_WIDTH){product[2*DATA_WIDTH-1]}},
                                          product};  // Sign-extend product to ACCUM_WIDTH

                if (tap_count == KERNEL_SIZE[($clog2(KERNEL_SIZE+1)-1):0] - 1) begin
                    // Last tap of this output pixel
                    accum_out <= accum_reg + {{(ACCUM_WIDTH-2*DATA_WIDTH){product[2*DATA_WIDTH-1]}},
                                              product};
                    valid_out <= 1'b1;
                    tap_count <= '0;
                    accum_reg <= '0;
                end else begin
                    tap_count <= tap_count + 1;
                end
            end
        end
    end

endmodule
