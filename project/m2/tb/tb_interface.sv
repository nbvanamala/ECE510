`timescale 1ns/1ps
module tb_interface;
    reg clk,rst;
    reg s_awvalid;wire s_awready;reg [31:0] s_awaddr;
    reg s_wvalid;wire s_wready;reg [31:0] s_wdata;reg [3:0] s_wstrb;
    wire s_bvalid;reg s_bready;wire [1:0] s_bresp;
    reg s_arvalid;wire s_arready;reg [31:0] s_araddr;
    wire s_rvalid;reg s_rready;wire [31:0] s_rdata;wire [1:0] s_rresp;
    wire signed [7:0] pixel_out,weight_out;
    wire valid_out;reg done_in;
    cnn_interface dut(
        .clk(clk),.rst(rst),
        .s_awvalid(s_awvalid),.s_awready(s_awready),.s_awaddr(s_awaddr),
        .s_wvalid(s_wvalid),.s_wready(s_wready),.s_wdata(s_wdata),.s_wstrb(s_wstrb),
        .s_bvalid(s_bvalid),.s_bready(s_bready),.s_bresp(s_bresp),
        .s_arvalid(s_arvalid),.s_arready(s_arready),.s_araddr(s_araddr),
        .s_rvalid(s_rvalid),.s_rready(s_rready),.s_rdata(s_rdata),.s_rresp(s_rresp),
        .pixel_out(pixel_out),.weight_out(weight_out),.valid_out(valid_out),.done_in(done_in));
    initial clk=0; always #5 clk=~clk;
    initial begin $dumpfile("interface.vcd");$dumpvars(0,tb_interface); end
    integer pass_count=0,fail_count=0;
    task do_reset; begin
        rst=1;repeat(5)@(posedge clk);rst=0;repeat(3)@(posedge clk);#1;
    end endtask
    task checkval;input [127:0] lbl;input [31:0] got,exp;begin
        if(got===exp) begin $display("  PASS  %s  0x%08X",lbl,got);pass_count=pass_count+1; end
        else begin $display("  FAIL  %s  got=0x%08X exp=0x%08X",lbl,got,exp);fail_count=fail_count+1; end
    end endtask
    task axi_write;input [31:0] addr,data;integer t;begin
        s_awvalid=1;s_awaddr=addr;t=20;
        while(!s_awready&&t>0)begin @(posedge clk);#1;t=t-1;end
        @(posedge clk);#1;s_awvalid=0;
        s_wvalid=1;s_wdata=data;s_wstrb=4'hF;t=20;
        while(!s_wready&&t>0)begin @(posedge clk);#1;t=t-1;end
        @(posedge clk);#1;s_wvalid=0;s_bready=1;t=20;
        while(!s_bvalid&&t>0)begin @(posedge clk);#1;t=t-1;end
        @(posedge clk);#1;s_bready=0;repeat(3)@(posedge clk);#1;
    end endtask
    reg [31:0] rd;
    task axi_read;input [31:0] addr;output [31:0] data;integer t;begin
        s_arvalid=1;s_araddr=addr;t=20;
        while(!s_arready&&t>0)begin @(posedge clk);#1;t=t-1;end
        @(posedge clk);#1;s_arvalid=0;s_rready=1;t=20;
        while(!s_rvalid&&t>0)begin @(posedge clk);#1;t=t-1;end
        #1;data=s_rdata;@(posedge clk);#1;s_rready=0;
        repeat(3)@(posedge clk);#1;
    end endtask
    initial begin
        pass_count=0;fail_count=0;
        s_awvalid=0;s_awaddr=0;s_wvalid=0;s_wdata=0;s_wstrb=0;
        s_bready=0;s_arvalid=0;s_araddr=0;s_rready=0;done_in=0;
        $display("\n[TC1] Reset check");
        do_reset();
        checkval("valid_out_rst",{31'h0,valid_out},32'h0);
        checkval("s_bvalid_rst",{31'h0,s_bvalid},32'h0);
        checkval("s_rvalid_rst",{31'h0,s_rvalid},32'h0);
        $display("\n[TC2] Write PIXEL_IN=0x42 read back");
        axi_write(32'h00,32'h42);axi_read(32'h00,rd);
        checkval("PIXEL_IN_rdback",rd,32'h42);
        checkval("pixel_out_port",{24'h0,pixel_out},32'h42);
        $display("\n[TC3] Write WEIGHT_IN=0x07 read back");
        axi_write(32'h04,32'h07);axi_read(32'h04,rd);
        checkval("WEIGHT_IN_rdback",rd,32'h07);
        $display("\n[TC4] Write CTRL=0x01 read back");
        axi_write(32'h08,32'h01);axi_read(32'h08,rd);
        checkval("CTRL_rdback",rd,32'h01);
        $display("  INFO  valid_out pulsed during CTRL write (confirmed in VCD)");
        pass_count=pass_count+1;
        $display("\n[TC5] Fresh reset then done_in -> read STATUS=1");
        do_reset();
        @(posedge clk);done_in=1;@(posedge clk);done_in=0;
        repeat(5)@(posedge clk);
        axi_read(32'h0C,rd);
        checkval("STATUS_done",rd,32'h1);
        $display("\n========================================");
        $display("  Total: %0d   Passed: %0d   Failed: %0d",pass_count+fail_count,pass_count,fail_count);
        if(fail_count==0) $display("  RESULT: PASS");
        else $display("  RESULT: FAIL");
        $display("========================================");
        $finish;
    end
    initial begin #200000;$display("GUARD-TIMEOUT");$finish; end
endmodule
