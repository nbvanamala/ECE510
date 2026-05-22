`timescale 1ns/1ps
module tb_top;
reg clk=0,rst=1;
reg s_awvalid=0;wire s_awready;reg[31:0]s_awaddr=0;
reg s_wvalid=0;wire s_wready;reg[31:0]s_wdata=0;reg[3:0]s_wstrb=4'hF;
wire s_bvalid;reg s_bready=0;wire[1:0]s_bresp;
reg s_arvalid=0;wire s_arready;reg[31:0]s_araddr=0;
wire s_rvalid;reg s_rready=0;wire[31:0]s_rdata;wire[1:0]s_rresp;
wire[127:0]result_out;
top #(.NUM_PE(4),.DATA_WIDTH(8),.ACCUM_WIDTH(32),.KERNEL_SIZE(9),.ADDR_WIDTH(32),.AXI_DW(32)) dut(
.clk(clk),.rst(rst),
.s_awvalid(s_awvalid),.s_awready(s_awready),.s_awaddr(s_awaddr),
.s_wvalid(s_wvalid),.s_wready(s_wready),.s_wdata(s_wdata),.s_wstrb(s_wstrb),
.s_bvalid(s_bvalid),.s_bready(s_bready),.s_bresp(s_bresp),
.s_arvalid(s_arvalid),.s_arready(s_arready),.s_araddr(s_araddr),
.s_rvalid(s_rvalid),.s_rready(s_rready),.s_rdata(s_rdata),.s_rresp(s_rresp),
.result_out(result_out));
always #5 clk=~clk;
initial begin $dumpfile("cosim_waveform.vcd");$dumpvars(0,tb_top);end
reg[31:0]wr_addr,wr_data;reg wr_req=0,wr_done=0;reg[2:0]wr_st=0;
always @(posedge clk) begin
if(rst)begin wr_st<=0;s_awvalid<=0;s_wvalid<=0;s_bready<=0;wr_done<=0;end
else begin wr_done<=0;
case(wr_st)
3'd0:if(wr_req)begin s_awvalid<=1;s_awaddr<=wr_addr;wr_st<=1;end
3'd1:if(s_awvalid&&s_awready)begin s_awvalid<=0;wr_st<=2;end
3'd2:wr_st<=3;
3'd3:begin s_wvalid<=1;s_wdata<=wr_data;s_wstrb<=4'hF;
if(s_wvalid&&s_wready)begin s_wvalid<=0;s_bready<=1;wr_st<=4;end end
3'd4:if(s_bvalid&&s_bready)begin s_bready<=0;wr_done<=1;wr_st<=0;end
endcase end end
task axi_write;input[31:0]addr,data;integer t;begin
@(posedge clk);#1;wr_addr=addr;wr_data=data;wr_req=1;
@(posedge clk);#1;wr_req=0;
t=0;while(!wr_done&&t<500)begin @(posedge clk);#1;t=t+1;end
end endtask
reg[31:0]rd_addr,rd_data_out;reg rd_req=0,rd_done=0;reg[1:0]rd_st=0;
always @(posedge clk) begin
if(rst)begin rd_st<=0;s_arvalid<=0;s_rready<=0;rd_done<=0;end
else begin rd_done<=0;
case(rd_st)
2'd0:if(rd_req)begin s_arvalid<=1;s_araddr<=rd_addr;rd_st<=1;end
2'd1:if(s_arvalid&&s_arready)begin s_arvalid<=0;s_rready<=1;rd_st<=2;end
2'd2:if(s_rvalid&&s_rready)begin rd_data_out<=s_rdata;s_rready<=0;rd_done<=1;rd_st<=0;end
endcase end end
task axi_read;input[31:0]addr;output[31:0]rdata;integer t;begin
@(posedge clk);#1;rd_addr=addr;rd_req=1;
@(posedge clk);#1;rd_req=0;
t=0;while(!rd_done&&t<500)begin @(posedge clk);#1;t=t+1;end
rdata=rd_data_out;
end endtask
localparam ADDR_PIXEL_IN=32'h00,ADDR_WEIGHT_IN=32'h04,ADDR_CTRL=32'h08;
localparam ADDR_RESULT0=32'h10,ADDR_RESULT1=32'h14,ADDR_RESULT2=32'h18,ADDR_RESULT3=32'h1C;
localparam ADDR_DONE=32'h20;
reg signed[31:0]expected[0:3];
reg[7:0]pixel_tap[0:8];
integer i,fail_count;reg[31:0]rval;reg signed[31:0]got;integer poll_count;
initial begin
fail_count=0;
expected[0]=32'sd135;expected[1]=32'sd315;
expected[2]=-32'sd90;expected[3]=32'sd225;
pixel_tap[0]=8'd1;pixel_tap[1]=8'd2;pixel_tap[2]=8'd3;
pixel_tap[3]=8'd4;pixel_tap[4]=8'd5;pixel_tap[5]=8'd6;
pixel_tap[6]=8'd7;pixel_tap[7]=8'd8;pixel_tap[8]=8'd9;
repeat(5)@(posedge clk);rst=0;repeat(3)@(posedge clk);
$display("[REGION 1] Writing PE weights via AXI4-Lite WEIGHT_IN (0x04)");
axi_write(ADDR_WEIGHT_IN,32'd3);$display("[REGION 1] PE0 weight=3");
axi_write(ADDR_WEIGHT_IN,32'd7);$display("[REGION 1] PE1 weight=7");
axi_write(ADDR_WEIGHT_IN,32'hFE);$display("[REGION 1] PE2 weight=-2 (0xFE as INT8)");
axi_write(ADDR_WEIGHT_IN,32'd5);$display("[REGION 1] PE3 weight=5");
repeat(2)@(posedge clk);
$display("[REGION 2] Streaming 9 distinct pixel taps via AXI4-Lite (pixels 1..9)");
for(i=0;i<9;i=i+1)begin
axi_write(ADDR_PIXEL_IN,{24'd0,pixel_tap[i]});
axi_write(ADDR_CTRL,32'h1);
$display("[REGION 2] Tap %0d: pixel=%0d",i,pixel_tap[i]);
end
$display("[REGION 3] Polling DONE register (0x20) via AXI4-Lite read");
rval=0;poll_count=0;
while(rval[0]!==1'b1&&poll_count<100)begin
axi_read(ADDR_DONE,rval);poll_count=poll_count+1;
end
if(rval[0]!==1'b1)begin $display("FAIL (timeout)");$finish;end
$display("[REGION 3] DONE=1 after %0d poll(s)",poll_count);
axi_read(ADDR_RESULT0,rval);got=$signed(rval);
$display("[REGION 3] PE0: got=%0d expected=%0d %s",got,expected[0],(got===expected[0])?"OK":"MISMATCH");
if(got!==expected[0])fail_count=fail_count+1;
axi_read(ADDR_RESULT1,rval);got=$signed(rval);
$display("[REGION 3] PE1: got=%0d expected=%0d %s",got,expected[1],(got===expected[1])?"OK":"MISMATCH");
if(got!==expected[1])fail_count=fail_count+1;
axi_read(ADDR_RESULT2,rval);got=$signed(rval);
$display("[REGION 3] PE2: got=%0d expected=%0d %s",got,expected[2],(got===expected[2])?"OK":"MISMATCH");
if(got!==expected[2])fail_count=fail_count+1;
axi_read(ADDR_RESULT3,rval);got=$signed(rval);
$display("[REGION 3] PE3: got=%0d expected=%0d %s",got,expected[3],(got===expected[3])?"OK":"MISMATCH");
if(got!==expected[3])fail_count=fail_count+1;
repeat(5)@(posedge clk);
if(fail_count==0)$display("PASS");
else $display("FAIL (%0d errors)",fail_count);
$finish;
end
initial begin #5000000;$display("FAIL (timeout)");$finish;end
endmodule
