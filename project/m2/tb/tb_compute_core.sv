`timescale 1ns/1ps
module tb_compute_core;
    localparam NUM_PE=4,DATA_WIDTH=8,ACCUM_WIDTH=32,KERNEL_SIZE=9;
    reg clk=0,rst=0;
    reg signed [DATA_WIDTH-1:0] pixel_in=0,weight_din=0;
    reg valid_in=0,weight_wr=0;
    reg [1:0] weight_addr=0;
    wire [NUM_PE*ACCUM_WIDTH-1:0] result_data;
    wire result_valid;
    wire signed [ACCUM_WIDTH-1:0] pe0_result;
    assign pe0_result=$signed(result_data[ACCUM_WIDTH-1:0]);
    compute_core #(.NUM_PE(NUM_PE),.DATA_WIDTH(DATA_WIDTH),.ACCUM_WIDTH(ACCUM_WIDTH),.KERNEL_SIZE(KERNEL_SIZE)) dut (
        .clk(clk),.rst(rst),.pixel_in(pixel_in),.valid_in(valid_in),
        .weight_wr(weight_wr),.weight_addr(weight_addr),.weight_din(weight_din),
        .result_data(result_data),.result_valid(result_valid));
    initial begin $dumpfile("compute_core.vcd");$dumpvars(0,tb_compute_core); end
    always #5 clk=~clk;
    integer pass_count=0,fail_count=0;
    task load_w0; input signed [7:0] w; begin
        @(posedge clk);#1;weight_wr=1;weight_addr=0;weight_din=w;
        @(posedge clk);#1;weight_wr=0;repeat(2)@(posedge clk);#1;
    end endtask
    task check_kernel; input signed [7:0] p; input signed [31:0] exp; input [255:0] lbl;
        integer k,timeout; begin
            valid_in=1;pixel_in=p;
            for(k=0;k<KERNEL_SIZE;k=k+1) begin @(posedge clk);#1; end
            valid_in=0;pixel_in=0;
            timeout=15;
            while(!result_valid&&timeout>0) begin @(posedge clk);#1;timeout=timeout-1; end
            if(pe0_result===exp) begin
                $display("PASS  [%0s] pe0=%0d (expected %0d)",lbl,$signed(pe0_result),exp);
                pass_count=pass_count+1;
            end else begin
                $display("FAIL  [%0s] pe0=%0d (expected %0d)",lbl,$signed(pe0_result),exp);
                fail_count=fail_count+1;
            end
            repeat(4)@(posedge clk);#1;
        end
    endtask
    initial begin
        rst=1;repeat(4)@(posedge clk);#1;rst=0;@(posedge clk);#1;
        if(result_valid===1'b0&&result_data===0) begin
            $display("PASS  [Reset] result_valid=0, result_data=0");pass_count=pass_count+1;
        end else begin $display("FAIL  [Reset]");fail_count=fail_count+1; end
        load_w0(8'sd1); check_kernel(8'sd1, 32'sd9,   "All-ones 9*(1*1)=9");
        load_w0(8'sd7); check_kernel(8'sd3, 32'sd189, "Representative 9*(3*7)=189");
        load_w0(-8'sd3);check_kernel(8'sd5,-32'sd135, "Negative 9*(5*-3)=-135");
        $display("------------------------------------");
        $display("Tests passed: %0d / %0d",pass_count,pass_count+fail_count);
        if(fail_count==0) $display("PASS");
        else $display("FAIL  (%0d test(s) failed)",fail_count);
        $display("------------------------------------");
        $finish;
    end
endmodule
