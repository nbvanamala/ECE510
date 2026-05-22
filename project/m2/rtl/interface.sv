// ============================================================
// interface.sv  —  AXI4-Lite Slave Interface Module
// Project  : Edge CNN Accelerator for Industrial AI Applications
// Course   : ECE510 Spring 2026
// Author   : Naveen Babu Vanamala
// File     : project/m2/rtl/interface.sv
//
// Description
//   AXI4-Lite slave interface connecting the host CPU to the
//   Edge CNN Accelerator compute core. The host writes pixel
//   and weight values via AXI4-Lite, triggers computation via
//   the CTRL register, and reads back the STATUS register.
//   Protocol: ARM AMBA AXI4-Lite (IHI0022E).
//   Handshake implemented on all 5 channels:
//     Write address (AW), Write data (W), Write response (B),
//     Read address (AR), Read data (R).
//   BRESP and RRESP always return OKAY (2'b00).
//
// Clock domain : Single clock (clk), rising-edge triggered.
//                No clock-domain crossings.
// Reset        : Synchronous, active-HIGH (rst).
//                All registers and FSM states cleared on rst=1.
//
// Register Map (word-aligned, 4-byte addresses)
//   0x00  PIXEL_IN   [7:0]   Write/Read  Signed INT8 pixel value
//   0x04  WEIGHT_IN  [7:0]   Write/Read  Signed INT8 weight value
//   0x08  CTRL       [0]     Write/Read  Write 1: pulse valid_out (self-clearing)
//   0x0C  STATUS     [0]     Read-only   Set to 1 when done_in asserted
//
// Port List
//   clk        : input   1b        System clock, rising-edge triggered
//   rst        : input   1b        Synchronous active-high reset
//   s_awvalid  : input   1b        Master: write address valid
//   s_awready  : output  1b        Slave:  ready to accept write address
//   s_awaddr   : input   32b       Write address (word-aligned)
//   s_wvalid   : input   1b        Master: write data valid
//   s_wready   : output  1b        Slave:  ready to accept write data
//   s_wdata    : input   32b       Write data
//   s_wstrb    : input   4b        Byte strobes for write data
//   s_bvalid   : output  1b        Slave:  write response valid
//   s_bready   : input   1b        Master: ready to accept response
//   s_bresp    : output  2b        Write response (always OKAY = 2'b00)
//   s_arvalid  : input   1b        Master: read address valid
//   s_arready  : output  1b        Slave:  ready to accept read address
//   s_araddr   : input   32b       Read address (word-aligned)
//   s_rvalid   : output  1b        Slave:  read data valid
//   s_rready   : input   1b        Master: ready to accept read data
//   s_rdata    : output  32b       Read data
//   s_rresp    : output  2b        Read response (always OKAY = 2'b00)
//   pixel_out  : output  8b signed INT8 pixel value (to compute core)
//   weight_out : output  8b signed INT8 weight value (to compute core)
//   valid_out  : output  1b        Start pulse to compute core (one cycle)
//   done_in    : input   1b        Done signal from compute core
// ============================================================

module axi4lite_slave #(
    parameter DATA_WIDTH=8, ADDR_WIDTH=32, AXI_DW=32
) (
    input  wire clk, rst,
    input  wire s_awvalid, output reg s_awready, input wire [ADDR_WIDTH-1:0] s_awaddr,
    input  wire s_wvalid, output reg s_wready, input wire [AXI_DW-1:0] s_wdata,
    input  wire [AXI_DW/8-1:0] s_wstrb,
    output reg s_bvalid, input wire s_bready, output reg [1:0] s_bresp,
    input  wire s_arvalid, output reg s_arready, input wire [ADDR_WIDTH-1:0] s_araddr,
    output reg s_rvalid, input wire s_rready, output reg [AXI_DW-1:0] s_rdata,
    output reg [1:0] s_rresp,
    output reg signed [DATA_WIDTH-1:0] pixel_out, weight_out,
    output reg valid_out, input wire done_in
);
    reg [AXI_DW-1:0] reg_pixel,reg_weight,reg_ctrl,reg_status;
    reg [1:0] wr_state; reg [ADDR_WIDTH-1:0] wr_addr_lat;
    localparam WR_IDLE=0,WR_DATA=1,WR_RESP=2;
    always @(posedge clk) begin
        if (rst) begin
            wr_state<=WR_IDLE;s_awready<=0;s_wready<=0;s_bvalid<=0;s_bresp<=0;
            reg_pixel<=0;reg_weight<=0;reg_ctrl<=0;valid_out<=0;
        end else begin
            valid_out<=0;
            case(wr_state)
                WR_IDLE: begin s_awready<=1;s_wready<=0;
                    if(s_awvalid&s_awready) begin wr_addr_lat<=s_awaddr;s_awready<=0;s_wready<=1;wr_state<=WR_DATA; end end
                WR_DATA: begin
                    if(s_wvalid&s_wready) begin s_wready<=0;
                        case(wr_addr_lat[3:0])
                            4'h0: reg_pixel<=s_wdata;
                            4'h4: reg_weight<=s_wdata;
                            4'h8: begin reg_ctrl<=s_wdata; if(s_wdata[0]) valid_out<=1; end
                        endcase
                        s_bvalid<=1;s_bresp<=0;wr_state<=WR_RESP; end end
                WR_RESP: begin if(s_bvalid&s_bready) begin s_bvalid<=0;wr_state<=WR_IDLE; end end
            endcase
        end
    end
    always @(posedge clk) begin
        if(rst) reg_status<=0;
        else if(done_in) reg_status<=1;
        else if(reg_ctrl[0]) reg_status<=0;
    end
    reg [1:0] rd_state; localparam RD_IDLE=0,RD_DATA=1;
    always @(posedge clk) begin
        if(rst) begin rd_state<=RD_IDLE;s_arready<=0;s_rvalid<=0;s_rdata<=0;s_rresp<=0; end
        else case(rd_state)
            RD_IDLE: begin s_arready<=1;
                if(s_arvalid&s_arready) begin s_arready<=0;
                    case(s_araddr[3:0])
                        4'h0:s_rdata<=reg_pixel; 4'h4:s_rdata<=reg_weight;
                        4'h8:s_rdata<=reg_ctrl;  4'hC:s_rdata<=reg_status;
                        default:s_rdata<=32'hDEADBEEF;
                    endcase
                    s_rresp<=0;s_rvalid<=1;rd_state<=RD_DATA; end end
            RD_DATA: begin if(s_rvalid&s_rready) begin s_rvalid<=0;rd_state<=RD_IDLE; end end
        endcase
    end
    always @(posedge clk) begin
        if(rst) begin pixel_out<=0;weight_out<=0; end
        else begin pixel_out<=reg_pixel[DATA_WIDTH-1:0];weight_out<=reg_weight[DATA_WIDTH-1:0]; end
    end
endmodule

module cnn_interface #(parameter DATA_WIDTH=8,ADDR_WIDTH=32,AXI_DW=32) (
    input  wire clk,rst,
    input  wire s_awvalid,output wire s_awready,input wire [ADDR_WIDTH-1:0] s_awaddr,
    input  wire s_wvalid,output wire s_wready,input wire [AXI_DW-1:0] s_wdata,
    input  wire [AXI_DW/8-1:0] s_wstrb,
    output wire s_bvalid,input wire s_bready,output wire [1:0] s_bresp,
    input  wire s_arvalid,output wire s_arready,input wire [ADDR_WIDTH-1:0] s_araddr,
    output wire s_rvalid,input wire s_rready,output wire [AXI_DW-1:0] s_rdata,
    output wire [1:0] s_rresp,
    output wire signed [DATA_WIDTH-1:0] pixel_out,weight_out,
    output wire valid_out,input wire done_in
);
    axi4lite_slave #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH),.AXI_DW(AXI_DW)) u_slave (.*);
endmodule
