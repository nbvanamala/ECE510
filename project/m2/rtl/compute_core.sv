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
