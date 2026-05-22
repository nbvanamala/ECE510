module conv_pe #(
    parameter DATA_WIDTH  = 8,
    parameter ACCUM_WIDTH = 32,
    parameter KERNEL_SIZE = 9
) (
    input  wire                          clk,
    input  wire                          rst,
    input  wire                          valid_in,
    input  wire signed [DATA_WIDTH-1:0]  pixel_in,
    input  wire signed [DATA_WIDTH-1:0]  weight_in,
    output reg  signed [ACCUM_WIDTH-1:0] accum_out,
    output reg                           valid_out
);
    wire signed [2*DATA_WIDTH-1:0] product;
    assign product = pixel_in * weight_in;
    wire signed [ACCUM_WIDTH-1:0] product_ext;
    assign product_ext = {{(ACCUM_WIDTH-2*DATA_WIDTH){product[2*DATA_WIDTH-1]}}, product};
    reg signed [ACCUM_WIDTH-1:0] accum_reg;
    reg [3:0] tap_count;
    always @(posedge clk) begin
        if (rst) begin
            accum_reg<=0; accum_out<=0; tap_count<=0; valid_out<=0;
        end else begin
            valid_out<=1'b0;
            if (valid_in) begin
                if (tap_count==KERNEL_SIZE-1) begin
                    accum_out<=accum_reg+product_ext;
                    valid_out<=1'b1; tap_count<=0; accum_reg<=0;
                end else begin
                    accum_reg<=accum_reg+product_ext;
                    tap_count<=tap_count+1;
                end
            end
        end
    end
endmodule
