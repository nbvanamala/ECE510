// ============================================================
// top.sv — Integrated Top Module
// Project : Edge CNN Accelerator Using a Weight-Stationary Systolic Array
// Course  : ECE510 Spring 2026
// Author  : Naveen Babu Vanamala
//
// Port List:
//   clk        : input   1b     System clock, rising-edge
//   rst        : input   1b     Synchronous active-high reset
//   s_awvalid  : input   1b     AXI write address valid
//   s_awready  : output  1b     AXI write address ready
//   s_awaddr   : input  32b     AXI write address
//   s_wvalid   : input   1b     AXI write data valid
//   s_wready   : output  1b     AXI write data ready
//   s_wdata    : input  32b     AXI write data
//   s_wstrb    : input   4b     AXI write byte strobes
//   s_bvalid   : output  1b     AXI write response valid
//   s_bready   : input   1b     AXI write response ready
//   s_bresp    : output  2b     AXI write response (OKAY)
//   s_arvalid  : input   1b     AXI read address valid
//   s_arready  : output  1b     AXI read address ready
//   s_araddr   : input  32b     AXI read address
//   s_rvalid   : output  1b     AXI read data valid
//   s_rready   : input   1b     AXI read data ready
//   s_rdata    : output 32b     AXI read data
//   s_rresp    : output  2b     AXI read response (OKAY)
//   result_out : output 128b    Packed PE results [PE3|PE2|PE1|PE0]
//
// Glue Logic:
//   1. weight_wr_raw->weight_wr_r: 1-cycle delay for weight_out settling
//   2. valid_in_delayed: 1-cycle delay for pixel_out settling
//   3. reg_result[0:3]: result capture at 0x10-0x1C
//   4. reg_done: sticky DONE flag at 0x20
// ============================================================
`timescale 1ns/1ps
module top #(
parameter NUM_PE=4,parameter DATA_WIDTH=8,parameter ACCUM_WIDTH=32,
parameter KERNEL_SIZE=9,parameter ADDR_WIDTH=32,parameter AXI_DW=32
)(
input wire clk,rst,
input wire s_awvalid,output wire s_awready,input wire[31:0]s_awaddr,
input wire s_wvalid,output wire s_wready,input wire[31:0]s_wdata,input wire[3:0]s_wstrb,
output wire s_bvalid,input wire s_bready,output wire[1:0]s_bresp,
input wire s_arvalid,output wire s_arready,input wire[31:0]s_araddr,
output wire s_rvalid,input wire s_rready,output wire[31:0]s_rdata,output wire[1:0]s_rresp,
output wire[127:0]result_out
);
wire signed[7:0]w_pixel_out,w_weight_out;
wire w_valid_out;
reg aw_is_weight,weight_wr_raw,weight_wr_r;
reg[1:0]w_addr_ctr,weight_addr_r,weight_addr_raw;
always @(posedge clk) begin
if(rst)begin aw_is_weight<=0;w_addr_ctr<=0;weight_wr_raw<=0;weight_wr_r<=0;weight_addr_r<=0;weight_addr_raw<=0;end
else begin
weight_wr_raw<=0;
if(s_awvalid&&s_awready) aw_is_weight<=(s_awaddr[4:0]==5'h04);
if(s_wvalid&&s_wready&&aw_is_weight)begin weight_wr_raw<=1;weight_addr_raw<=w_addr_ctr;w_addr_ctr<=w_addr_ctr+1;aw_is_weight<=0;end
weight_wr_r<=weight_wr_raw;weight_addr_r<=weight_addr_raw;
end end
reg valid_in_delayed;
always @(posedge clk) begin if(rst)valid_in_delayed<=0;else valid_in_delayed<=w_valid_out;end
wire[127:0]core_result_data;
wire core_result_valid;
compute_core #(.NUM_PE(NUM_PE),.DATA_WIDTH(DATA_WIDTH),.ACCUM_WIDTH(ACCUM_WIDTH),.KERNEL_SIZE(KERNEL_SIZE)) u_core(
.clk(clk),.rst(rst),.pixel_in(w_pixel_out),.valid_in(valid_in_delayed),
.weight_wr(weight_wr_r),.weight_addr(weight_addr_r),.weight_din(w_weight_out),
.result_data(core_result_data),.result_valid(core_result_valid));
assign result_out=core_result_data;
wire w_done_in;
assign w_done_in=core_result_valid;
reg[31:0]reg_result[0:3];
reg reg_done;
integer ri;
always @(posedge clk) begin
if(rst)begin reg_done<=0;for(ri=0;ri<4;ri=ri+1)reg_result[ri]<=0;end
else begin
if(core_result_valid)begin
reg_done<=1;
for(ri=0;ri<4;ri=ri+1)reg_result[ri]<=core_result_data[ri*32+:32];
end
if(top_rd_fire&&(top_rd_addr[7:0]==8'h20))reg_done<=0;
end end
wire addr_is_top=(s_araddr[7:4]!=4'h0);
wire if_arvalid=s_arvalid&&!addr_is_top;
wire if_arready,if_rvalid;
wire[31:0]if_rdata;
wire[1:0]if_rresp;
reg top_arready_r,top_rvalid_r;
reg[31:0]top_rdata_r,top_rd_addr;
reg[1:0]top_rd_st;
wire top_rd_fire=top_rvalid_r&&s_rready;
always @(posedge clk) begin
if(rst)begin top_rd_st<=0;top_arready_r<=0;top_rvalid_r<=0;top_rdata_r<=0;top_rd_addr<=0;end
else begin
case(top_rd_st)
2'd0:begin top_arready_r<=1;
if(s_arvalid&&top_arready_r&&addr_is_top)begin top_rd_addr<=s_araddr;top_arready_r<=0;top_rd_st<=1;end end
2'd1:begin
case(top_rd_addr[7:0])
8'h10:top_rdata_r<=reg_result[0];
8'h14:top_rdata_r<=reg_result[1];
8'h18:top_rdata_r<=reg_result[2];
8'h1C:top_rdata_r<=reg_result[3];
8'h20:top_rdata_r<={31'd0,reg_done};
default:top_rdata_r<=32'hDEAD0010;
endcase
top_rvalid_r<=1;top_rd_st<=2;end
2'd2:if(top_rvalid_r&&s_rready)begin top_rvalid_r<=0;top_rd_st<=0;end
endcase end end
assign s_arready=addr_is_top?top_arready_r:if_arready;
assign s_rvalid=addr_is_top?top_rvalid_r:if_rvalid;
assign s_rdata=addr_is_top?top_rdata_r:if_rdata;
assign s_rresp=addr_is_top?2'b00:if_rresp;
cnn_interface #(.DATA_WIDTH(8),.ADDR_WIDTH(32),.AXI_DW(32)) u_interface(
.clk(clk),.rst(rst),
.s_awvalid(s_awvalid),.s_awready(s_awready),.s_awaddr(s_awaddr),
.s_wvalid(s_wvalid),.s_wready(s_wready),.s_wdata(s_wdata),.s_wstrb(s_wstrb),
.s_bvalid(s_bvalid),.s_bready(s_bready),.s_bresp(s_bresp),
.s_arvalid(if_arvalid),.s_arready(if_arready),.s_araddr(s_araddr),
.s_rvalid(if_rvalid),.s_rready(s_rready),.s_rdata(if_rdata),.s_rresp(if_rresp),
.pixel_out(w_pixel_out),.weight_out(w_weight_out),.valid_out(w_valid_out),.done_in(w_done_in));
endmodule
