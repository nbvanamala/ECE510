// ============================================================
// top.sv - Integrated Top Module
// Project : Edge CNN Accelerator for Industrial AI Applications
// Course  : ECE510 Spring 2026
// Author  : Naveen Babu Vanamala
//
// Port List:
//   clk        : input   1b    System clock, rising-edge triggered
//   rst        : input   1b    Synchronous active-high reset
//   s_awvalid  : input   1b    AXI4-Lite write address valid
//   s_awready  : output  1b    AXI4-Lite write address ready
//   s_awaddr   : input   32b   AXI4-Lite write address
//   s_wvalid   : input   1b    AXI4-Lite write data valid
//   s_wready   : output  1b    AXI4-Lite write data ready
//   s_wdata    : input   32b   AXI4-Lite write data
//   s_wstrb    : input   4b    AXI4-Lite write strobes
//   s_bvalid   : output  1b    AXI4-Lite write response valid
//   s_bready   : input   1b    AXI4-Lite write response ready
//   s_bresp    : output  2b    AXI4-Lite write response (OKAY=00)
//   s_arvalid  : input   1b    AXI4-Lite read address valid
//   s_arready  : output  1b    AXI4-Lite read address ready
//   s_araddr   : input   32b   AXI4-Lite read address
//   s_rvalid   : output  1b    AXI4-Lite read data valid
//   s_rready   : input   1b    AXI4-Lite read data ready
//   s_rdata    : output  32b   AXI4-Lite read data
//   s_rresp    : output  2b    AXI4-Lite read response (OKAY=00)
//   result_out : output  128b  Packed PE results [PE3|PE2|PE1|PE0]
//
// Glue Logic:
//   1. weight_wr/weight_addr counter: The AXI bus has no PE address
//      concept. A 2-bit counter w_addr_ctr increments each time a
//      write to WEIGHT_IN (0x04) completes. weight_wr_raw fires on
//      the W-data phase, then weight_wr_r is delayed one cycle to
//      align with the registered weight_out output of the interface.
//   2. valid_in_delayed: interface valid_out fires on the CTRL write
//      cycle but pixel_out settles one cycle later. A one-cycle
//      register delays valid_in to align with the settled pixel value.
//   3. done_in: directly wired from compute_core result_valid.
//      Single clock domain, no FIFO or CDC needed.
// ============================================================
`timescale 1ns/1ps
module top #(parameter NUM_PE=4,parameter DATA_WIDTH=8,parameter ACCUM_WIDTH=32,parameter KERNEL_SIZE=9,parameter ADDR_WIDTH=32,parameter AXI_DW=32)(input wire clk,input wire rst,input wire s_awvalid,output wire s_awready,input wire [31:0] s_awaddr,input wire s_wvalid,output wire s_wready,input wire [31:0] s_wdata,input wire [3:0] s_wstrb,output wire s_bvalid,input wire s_bready,output wire [1:0] s_bresp,input wire s_arvalid,output wire s_arready,input wire [31:0] s_araddr,output wire s_rvalid,input wire s_rready,output wire [31:0] s_rdata,output wire [1:0] s_rresp,output wire [127:0] result_out);
wire signed [7:0] w_pixel_out,w_weight_out;
wire w_valid_out,w_done_in;
reg aw_is_weight,weight_wr_raw,weight_wr_r;
reg [1:0] w_addr_ctr,weight_addr_r,weight_addr_raw;
reg valid_in_delayed;
always @(posedge clk) begin
if(rst) begin aw_is_weight<=0;w_addr_ctr<=0;weight_wr_raw<=0;weight_wr_r<=0;weight_addr_r<=0;weight_addr_raw<=0;
end else begin
weight_wr_raw<=0;
if(s_awvalid&&s_awready) aw_is_weight<=(s_awaddr[3:0]==4'h4);
if(s_wvalid&&s_wready&&aw_is_weight) begin weight_wr_raw<=1;weight_addr_raw<=w_addr_ctr;w_addr_ctr<=w_addr_ctr+1;aw_is_weight<=0;end
weight_wr_r<=weight_wr_raw;weight_addr_r<=weight_addr_raw;
end end
always @(posedge clk) begin if(rst) valid_in_delayed<=0;else valid_in_delayed<=w_valid_out;end
wire [127:0] core_result_data;wire core_result_valid;
assign w_done_in=core_result_valid;assign result_out=core_result_data;
cnn_interface #(.DATA_WIDTH(8),.ADDR_WIDTH(32),.AXI_DW(32)) u_interface(.clk(clk),.rst(rst),.s_awvalid(s_awvalid),.s_awready(s_awready),.s_awaddr(s_awaddr),.s_wvalid(s_wvalid),.s_wready(s_wready),.s_wdata(s_wdata),.s_wstrb(s_wstrb),.s_bvalid(s_bvalid),.s_bready(s_bready),.s_bresp(s_bresp),.s_arvalid(s_arvalid),.s_arready(s_arready),.s_araddr(s_araddr),.s_rvalid(s_rvalid),.s_rready(s_rready),.s_rdata(s_rdata),.s_rresp(s_rresp),.pixel_out(w_pixel_out),.weight_out(w_weight_out),.valid_out(w_valid_out),.done_in(w_done_in));
compute_core #(.NUM_PE(4),.DATA_WIDTH(8),.ACCUM_WIDTH(32),.KERNEL_SIZE(9)) u_core(.clk(clk),.rst(rst),.pixel_in(w_pixel_out),.valid_in(valid_in_delayed),.weight_wr(weight_wr_r),.weight_addr(weight_addr_r),.weight_din(w_weight_out),.result_data(core_result_data),.result_valid(core_result_valid));
endmodule
