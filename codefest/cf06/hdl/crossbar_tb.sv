// Testbench for crossbar_mac
// Weights: [[1,-1,1,-1],[1,1,-1,-1],[-1,1,1,-1],[-1,-1,-1,1]]
// Input:   [10, 20, 30, 40]
// Expected: out[0]=-40, out[1]=0, out[2]=-20, out[3]=-20

`timescale 1ns/1ps

module crossbar_tb;

    reg        clk;
    reg        rst_n;
    reg        load_weights;
    reg signed [7:0]  in_vec   [0:3];
    reg signed [1:0]  w_init   [0:3][0:3];
    wire signed [11:0] out_vec  [0:3];

    crossbar_mac dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .load_weights (load_weights),
        .in_vec       (in_vec),
        .w_init       (w_init),
        .out_vec      (out_vec)
    );

    // 10 ns clock
    initial clk = 0;
    always #5 clk = ~clk;

    // Hand-calculated expected outputs
    // weight[i][j] layout:
    //   row 0: [+1, -1, +1, -1]
    //   row 1: [+1, +1, -1, -1]
    //   row 2: [-1, +1, +1, -1]
    //   row 3: [-1, -1, -1, +1]
    //
    // out[0] = (+1)*10 + (+1)*20 + (-1)*30 + (-1)*40 = 10+20-30-40 = -40
    // out[1] = (-1)*10 + (+1)*20 + (+1)*30 + (-1)*40 = -10+20+30-40 =   0
    // out[2] = (+1)*10 + (-1)*20 + (+1)*30 + (-1)*40 = 10-20+30-40  = -20
    // out[3] = (-1)*10 + (-1)*20 + (-1)*30 + (+1)*40 = -10-20-30+40 = -20

    task check_output(input string label,
                      input signed [11:0] got0, got1, got2, got3,
                      input signed [11:0] exp0, exp1, exp2, exp3);
        $display("--- %s ---", label);
        $display("out[0]: got=%0d  expected=%0d  %s", got0, exp0, (got0===exp0)?"PASS":"FAIL");
        $display("out[1]: got=%0d  expected=%0d  %s", got1, exp1, (got1===exp1)?"PASS":"FAIL");
        $display("out[2]: got=%0d  expected=%0d  %s", got2, exp2, (got2===exp2)?"PASS":"FAIL");
        $display("out[3]: got=%0d  expected=%0d  %s", got3, exp3, (got3===exp3)?"PASS":"FAIL");
        if (got0===exp0 && got1===exp1 && got2===exp2 && got3===exp3)
            $display("ALL PASS");
        else
            $display("MISMATCH DETECTED");
    endtask

    initial begin
        // Init
        rst_n        = 0;
        load_weights = 0;
        in_vec[0]    = 0;
        in_vec[1]    = 0;
        in_vec[2]    = 0;
        in_vec[3]    = 0;

        // Weights: row i = [w[i][0], w[i][1], w[i][2], w[i][3]]
        // +1 encoded as 2'b01, -1 encoded as 2'b11 (2-bit signed)
        // row 0: [+1, -1, +1, -1]
        w_init[0][0] =  2'sb01; w_init[0][1] =  2'sb11;
        w_init[0][2] =  2'sb01; w_init[0][3] =  2'sb11;
        // row 1: [+1, +1, -1, -1]
        w_init[1][0] =  2'sb01; w_init[1][1] =  2'sb01;
        w_init[1][2] =  2'sb11; w_init[1][3] =  2'sb11;
        // row 2: [-1, +1, +1, -1]
        w_init[2][0] =  2'sb11; w_init[2][1] =  2'sb01;
        w_init[2][2] =  2'sb01; w_init[2][3] =  2'sb11;
        // row 3: [-1, -1, -1, +1]
        w_init[3][0] =  2'sb11; w_init[3][1] =  2'sb11;
        w_init[3][2] =  2'sb11; w_init[3][3] =  2'sb01;

        @(posedge clk); #1;
        rst_n = 1;

        // Cycle 1: load weights
        load_weights = 1;
        @(posedge clk); #1;
        load_weights = 0;

        // Cycle 2: apply inputs
        in_vec[0] = 8'sd10;
        in_vec[1] = 8'sd20;
        in_vec[2] = 8'sd30;
        in_vec[3] = 8'sd40;
        @(posedge clk); #1;

        // Cycle 3: outputs are registered — read after this edge
        @(posedge clk); #1;

        check_output("Test: in=[10,20,30,40]",
                     out_vec[0], out_vec[1], out_vec[2], out_vec[3],
                     -40, 0, -20, -20);

        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("crossbar_tb.vcd");
        $dumpvars(0, crossbar_tb);
    end

endmodule
