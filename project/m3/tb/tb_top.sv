`timescale 1ns/1ps
module tb_top;
reg clk=0,rst=1;
reg s_awvalid=0;wire s_awready;reg [31:0] s_awaddr=0;
reg s_wvalid=0;wire s_wready;reg [31:0] s_wdata=0;reg [3:0] s_wstrb=4'hF;
wire s_bvalid;reg s_bready=0;wire [1:0] s_bresp;
reg s_arvalid=0;wire s_arready;reg [31:0] s_araddr=0;
wire s_rvalid;reg s_rready=0;wire [31:0] s_rdata;wire [1:0] s_rresp;
wire [127:0] result_out;
top #(.NUM_PE(4),.DATA_WIDTH(8),.ACCUM_WIDTH(32),.KERNEL_SIZE(9),.ADDR_WIDTH(32),.AXI_DW(32)) dut(.clk(clk),.rst(rst),.s_awvalid(s_awvalid),.s_awready(s_awready),.s_awaddr(s_awaddr),.s_wvalid(s_wvalid),.s_wready(s_wready),.s_wdata(s_wdata),.s_wstrb(s_wstrb),.s_bvalid(s_bvalid),.s_bready(s_bready),.s_bresp(s_bresp),.s_arvalid(s_arvalid),.s_arready(s_arready),.s_araddr(s_araddr),.s_rvalid(s_rvalid),.s_rready(s_rready),.s_rdata(s_rdata),.s_rresp(s_rresp),.result_out(result_out));
always #5 clk=~clk;
initial begin $dumpfile("cosim_waveform.vcd");$dumpvars(0,tb_top);end
reg [31:0] sm_addr,sm_data;reg sm_req=0,sm_done=0;reg [2:0] sm_st=0;
always @(posedge clk) begin
if(rst) begin sm_st<=0;s_awvalid<=0;s_wvalid<=0;s_bready<=0;sm_done<=0;end
else begin sm_done<=0;
case(sm_st)
3'd0:if(sm_req) begin s_awvalid<=1;s_awaddr<=sm_addr;sm_st<=1;end
3'd1:if(s_awvalid&&s_awready) begin s_awvalid<=0;sm_st<=2;end
3'd2:sm_st<=3;
3'd3:begin s_wvalid<=1;s_wdata<=sm_data;s_wstrb<=4'hF;if(s_wvalid&&s_wready) begin s_wvalid<=0;s_bready<=1;sm_st<=4;end end
3'd4:if(s_bvalid&&s_bready) begin s_bready<=0;sm_done<=1;sm_st<=0;end
endcase end end
task axi_write;input [31:0] addr,data;integer t;begin
@(posedge clk);#1;sm_addr=addr;sm_data=data;sm_req=1;
@(posedge clk);#1;sm_req=0;
t=0;while(!sm_done&&t<500) begin @(posedge clk);#1;t=t+1;end
end endtask
reg signed [31:0] expected[0:3];
integer i,fail_count;reg signed [31:0] got;
initial begin
fail_count=0;
expected[0]=32'sd108;expected[1]=32'sd252;expected[2]=-32'sd72;expected[3]=32'sd180;
repeat(5) @(posedge clk);rst=0;repeat(3) @(posedge clk);
$display("[REGION 1] Writing 4 PE weights");
axi_write(32'h04,32'd3);$display("[REGION 1] PE0 weight=3");
axi_write(32'h04,32'd7);$display("[REGION 1] PE1 weight=7");
axi_write(32'h04,32'hFE);$display("[REGION 1] PE2 weight=-2");
axi_write(32'h04,32'd5);$display("[REGION 1] PE3 weight=5");
repeat(3) @(posedge clk);
$display("[REGION 2] Streaming 9 pixel taps");
for(i=0;i<9;i=i+1) begin axi_write(32'h00,32'd4);axi_write(32'h08,32'h1);$display("[REGION 2] Tap %0d done",i);end
repeat(15) @(posedge clk);
$display("[REGION 3] Reading results");
for(i=0;i<4;i=i+1) begin
got=$signed(result_out[i*32+:32]);
$display("[REGION 3] PE%0d: got=%0d expected=%0d %s",i,got,expected[i],(got===expected[i])?"OK":"MISMATCH");
if(got!==expected[i]) fail_count=fail_count+1;
end
repeat(5) @(posedge clk);
if(fail_count==0) $display("PASS");
else $display("FAIL (%0d errors)",fail_count);
$finish;end
initial begin #2000000;$display("FAIL (timeout)");$finish;end
endmodule
