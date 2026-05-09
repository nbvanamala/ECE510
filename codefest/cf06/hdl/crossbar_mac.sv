// 4x4 binary-weight crossbar MAC unit
// out[j] = sum_i weight[i][j] * in[i], weights are +1 or -1
// Inputs: 8-bit signed; outputs: accumulator (12-bit signed to avoid overflow)

module crossbar_mac (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        load_weights,
    input  logic signed [7:0]  in_vec   [0:3],
    input  logic signed [1:0]  w_init   [0:3][0:3], // +1 or -1 encoded as 2'b01 / 2'b11
    output logic signed [11:0] out_vec  [0:3]
);

    logic signed [1:0] weight [0:3][0:3];

    // Weight register load
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 4; i++)
                for (int j = 0; j < 4; j++)
                    weight[i][j] <= 2'b01; // default +1
        end else if (load_weights) begin
            for (int i = 0; i < 4; i++)
                for (int j = 0; j < 4; j++)
                    weight[i][j] <= w_init[i][j];
        end
    end

    // MAC: out[j] = sum_i weight[i][j] * in[i]
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int j = 0; j < 4; j++)
                out_vec[j] <= '0;
        end else begin
            for (int j = 0; j < 4; j++) begin
                automatic logic signed [11:0] acc = '0;
                for (int i = 0; i < 4; i++)
                    acc += 12'(signed'(weight[i][j])) * 12'(signed'(in_vec[i]));
                out_vec[j] <= acc;
            end
        end
    end

endmodule
