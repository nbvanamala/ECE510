// ============================================================
// compute_core.sv  —  Weight-Stationary Systolic Array Core
// Project  : Edge CNN Accelerator for Industrial AI Applications
// Course   : ECE510 Spring 2026
// Author   : Naveen Babu Vanamala
// File     : project/m2/rtl/compute_core.sv
//
// Description
//   Top-level compute core. Instantiates NUM_PE=4 conv_pe units
//   in parallel. Each PE holds one stationary INT8 weight loaded
//   via the weight write port. The same pixel_in is broadcast to
//   all PEs every clock cycle. All PE dot-product results are
//   packed into a single wide output bus. result_valid pulses for
//   one cycle when the dot-product is ready.
//
// Clock domain : Single clock (clk), rising-edge triggered.
//                No clock-domain crossings.
// Reset        : Synchronous, active-HIGH (rst).
//                All registers cleared to 0 on rst=1.
//
// Port List
//   clk         : input   1b        System clock, rising-edge triggered
//   rst         : input   1b        Synchronous active-high reset
//   pixel_in    : input   8b signed INT8 pixel broadcast to all PEs
//   valid_in    : input   1b        pixel_in is valid this cycle
//   weight_wr   : input   1b        Write-enable for weight memory
//   weight_addr : input   2b        PE index to write (0 to NUM_PE-1)
//   weight_din  : input   8b signed INT8 weight value to store
//   result_data : output  128b      Packed 32b results [PE3|PE2|PE1|PE0]
//   result_valid: output  1b        Pulses HIGH for one cycle when done
//
// Submodule dependency : conv_pe.sv (must be compiled together)
// ============================================================

module compute_core #(
    parameter NUM_PE      = 4,
    parameter DATA_WIDTH  = 8,
    parameter ACCUM_WIDTH = 32,
    parameter KERNEL_SIZE = 9
) (
    input  wire                          clk,
    input  wire                          rst,
    input  wire signed [DATA_WIDTH-1:0]  pixel_in,
    input  wire                          valid_in,
    input  wire                          weight_wr,
    input  wire [1:0]                    weight_addr,
    input  wire signed [DATA_WIDTH-1:0]  weight_din,
    output reg  [NUM_PE*ACCUM_WIDTH-1:0] result_data,
    output reg                           result_valid
);
    reg signed [DATA_WIDTH-1:0] weight_mem [0:NUM_PE-1];
    integer wi;
    always @(posedge clk) begin
        if (rst) begin
            for (wi=0;wi<NUM_PE;wi=wi+1) weight_mem[wi]<=0;
        end else if (weight_wr) begin
            weight_mem[weight_addr]<=weight_din;
        end
    end
    wire signed [ACCUM_WIDTH-1:0] pe_accum [0:NUM_PE-1];
    wire pe_valid [0:NUM_PE-1];
    genvar gi;
    generate
        for (gi=0;gi<NUM_PE;gi=gi+1) begin : pe_array
            conv_pe #(.DATA_WIDTH(DATA_WIDTH),.ACCUM_WIDTH(ACCUM_WIDTH),.KERNEL_SIZE(KERNEL_SIZE)) u_pe (
                .clk(clk),.rst(rst),.valid_in(valid_in),
                .pixel_in(pixel_in),.weight_in(weight_mem[gi]),
                .accum_out(pe_accum[gi]),.valid_out(pe_valid[gi]));
        end
    endgenerate
    integer k;
    always @(posedge clk) begin
        if (rst) begin result_valid<=0; result_data<=0; end
        else begin
            result_valid<=pe_valid[0];
            for (k=0;k<NUM_PE;k=k+1)
                result_data[k*ACCUM_WIDTH+:ACCUM_WIDTH]<=pe_accum[k];
        end
    end
endmodule
