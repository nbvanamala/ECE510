// 4x4 binary-weight crossbar MAC unit
// out[j] = sum_i weight[i][j] * in[i], weights are +1 or -1
// Inputs: 8-bit signed; outputs: 12-bit signed accumulator
// Fully iverilog-compatible: flat packed arrays, no unpacked wires in generate

module crossbar_mac (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        load_weights,
    input  wire signed [7:0]  in_vec   [0:3],
    input  wire signed [1:0]  w_init   [0:3][0:3],
    output reg  signed [11:0] out_vec  [0:3]
);

    // Flatten weight storage to packed: weight_flat[row*4+col]
    reg signed [1:0] weight_flat [0:15];

    integer ii, jj;

    // Weight register load
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (ii = 0; ii < 16; ii = ii + 1)
                weight_flat[ii] <= 2'b01; // default +1
        end else if (load_weights) begin
            for (ii = 0; ii < 4; ii = ii + 1)
                for (jj = 0; jj < 4; jj = jj + 1)
                    weight_flat[ii*4 + jj] <= w_init[ii][jj];
        end
    end

    // MAC: out[j] = sum_i weight[i][j] * in[i]
    // weight[i][j] = weight_flat[i*4+j]
    // sign-extend 2-bit to 12-bit inline: {{10{w[1]}}, w}
    always @(posedge clk or negedge rst_n) begin : MAC_BLOCK
        reg signed [11:0] acc;
        integer i, j;
        if (!rst_n) begin
            for (j = 0; j < 4; j = j + 1)
                out_vec[j] <= 12'sd0;
        end else begin
            for (j = 0; j < 4; j = j + 1) begin
                acc = 12'sd0;
                for (i = 0; i < 4; i = i + 1) begin
                    // sign extend weight_flat[i*4+j] from 2b to 12b, multiply by in_vec[i]
                    acc = acc + ({{10{weight_flat[i*4+j][1]}}, weight_flat[i*4+j]} * $signed(in_vec[i]));
                end
                out_vec[j] <= acc;
            end
        end
    end

endmodule
