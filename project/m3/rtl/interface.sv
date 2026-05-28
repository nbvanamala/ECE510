// ============================================================
// interface.sv (M3) — AXI4-Lite Slave Interface, extended
// Project  : Edge CNN Accelerator for Industrial AI Applications
// Course   : ECE510 Spring 2026
// Author   : Naveen Babu Vanamala
// File     : project/m3/rtl/interface.sv
//
// Description
//   M3 extension of project/m2/rtl/interface.sv. Adds a 32-bit
//   result read-back port (result_in) exposed at register address
//   0x10, so the host can retrieve PE0's accumulated result via
//   the same AXI4-Lite bus after a computation completes.
//   All M2 register addresses and behavior are preserved.
//
// Register Map
//   0x00  PIXEL_IN   [7:0]   Write/Read  Signed INT8 pixel value
//   0x04  WEIGHT_IN  [7:0]   Write/Read  Signed INT8 weight value
//   0x08  CTRL       [0]     Write/Read  Write 1: trigger (self-clearing)
//   0x0C  STATUS     [0]     Read-only   Set when done_in asserted
//   0x10  RESULT     [31:0]  Read-only   PE0 accumulation result
//
// New Port (vs M2)
//   result_in : input  32b   PE0 accumulation result from top-level glue
//
// All other ports identical to project/m2/rtl/interface.sv.
// ============================================================

module axi4lite_slave #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 32,
    parameter AXI_DW     = 32
) (
    input  wire clk, rst,
    input  wire                    s_awvalid,
    output reg                     s_awready,
    input  wire [ADDR_WIDTH-1:0]   s_awaddr,
    input  wire                    s_wvalid,
    output reg                     s_wready,
    input  wire [AXI_DW-1:0]      s_wdata,
    input  wire [AXI_DW/8-1:0]    s_wstrb,
    output reg                     s_bvalid,
    input  wire                    s_bready,
    output reg  [1:0]              s_bresp,
    input  wire                    s_arvalid,
    output reg                     s_arready,
    input  wire [ADDR_WIDTH-1:0]   s_araddr,
    output reg                     s_rvalid,
    input  wire                    s_rready,
    output reg  [AXI_DW-1:0]      s_rdata,
    output reg  [1:0]              s_rresp,
    output reg  signed [DATA_WIDTH-1:0] pixel_out,
    output reg  signed [DATA_WIDTH-1:0] weight_out,
    output reg  valid_out,
    input  wire done_in,
    input  wire [AXI_DW-1:0] result_in
);
    reg [AXI_DW-1:0] reg_pixel, reg_weight, reg_ctrl, reg_status;
    reg [1:0]         wr_state;
    reg [ADDR_WIDTH-1:0] wr_addr_lat;
    localparam WR_IDLE = 2'd0, WR_DATA = 2'd1, WR_RESP = 2'd2;

    // Write channel FSM
    always @(posedge clk) begin
        if (rst) begin
            wr_state  <= WR_IDLE;
            s_awready <= 0; s_wready <= 0; s_bvalid <= 0; s_bresp <= 0;
            reg_pixel <= 0; reg_weight <= 0; reg_ctrl <= 0; valid_out <= 0;
        end else begin
            valid_out <= 0;
            case (wr_state)
                WR_IDLE: begin
                    s_awready <= 1;
                    s_wready  <= 0;
                    if (s_awvalid & s_awready) begin
                        wr_addr_lat <= s_awaddr;
                        s_awready   <= 0;
                        s_wready    <= 1;
                        wr_state    <= WR_DATA;
                    end
                end
                WR_DATA: begin
                    if (s_wvalid & s_wready) begin
                        s_wready <= 0;
                        case (wr_addr_lat[3:0])
                            4'h0: reg_pixel  <= s_wdata;
                            4'h4: reg_weight <= s_wdata;
                            4'h8: begin
                                reg_ctrl <= s_wdata;
                                if (s_wdata[0]) valid_out <= 1;
                            end
                        endcase
                        s_bvalid <= 1;
                        s_bresp  <= 0;
                        wr_state <= WR_RESP;
                    end
                end
                WR_RESP: begin
                    if (s_bvalid & s_bready) begin
                        s_bvalid <= 0;
                        wr_state <= WR_IDLE;
                    end
                end
                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    // STATUS register: set when done_in asserted, cleared only by reset.
    // M2 cleared STATUS when reg_ctrl[0]=1 (the stored register value), which
    // caused STATUS to be cleared every cycle after any CTRL write because
    // reg_ctrl is not self-clearing. M3 removes that incorrect clear path;
    // the host reads STATUS=1 and then resets the system to start a new run.
    always @(posedge clk) begin
        if (rst)          reg_status <= 0;
        else if (done_in) reg_status <= 1;
    end

    // Read channel FSM
    reg [1:0] rd_state;
    localparam RD_IDLE = 2'd0, RD_DATA = 2'd1;
    always @(posedge clk) begin
        if (rst) begin
            rd_state  <= RD_IDLE;
            s_arready <= 0; s_rvalid <= 0; s_rdata <= 0; s_rresp <= 0;
        end else case (rd_state)
            RD_IDLE: begin
                s_arready <= 1;
                if (s_arvalid & s_arready) begin
                    s_arready <= 0;
                    case (s_araddr[4:0])
                        5'h00: s_rdata <= reg_pixel;
                        5'h04: s_rdata <= reg_weight;
                        5'h08: s_rdata <= reg_ctrl;
                        5'h0C: s_rdata <= reg_status;
                        5'h10: s_rdata <= result_in;
                        default: s_rdata <= 32'hDEAD_BEEF;
                    endcase
                    s_rresp  <= 0;
                    s_rvalid <= 1;
                    rd_state <= RD_DATA;
                end
            end
            RD_DATA: begin
                if (s_rvalid & s_rready) begin
                    s_rvalid <= 0;
                    rd_state <= RD_IDLE;
                end
            end
            default: rd_state <= RD_IDLE;
        endcase
    end

    // Output registers (pixel_out and weight_out updated every cycle)
    always @(posedge clk) begin
        if (rst) begin
            pixel_out  <= 0;
            weight_out <= 0;
        end else begin
            pixel_out  <= reg_pixel[DATA_WIDTH-1:0];
            weight_out <= reg_weight[DATA_WIDTH-1:0];
        end
    end
endmodule

// Wrapper — identical port list to M2's cnn_interface, plus result_in
module cnn_interface #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 32,
    parameter AXI_DW     = 32
) (
    input  wire clk, rst,
    input  wire                    s_awvalid,
    output wire                    s_awready,
    input  wire [ADDR_WIDTH-1:0]   s_awaddr,
    input  wire                    s_wvalid,
    output wire                    s_wready,
    input  wire [AXI_DW-1:0]      s_wdata,
    input  wire [AXI_DW/8-1:0]    s_wstrb,
    output wire                    s_bvalid,
    input  wire                    s_bready,
    output wire [1:0]              s_bresp,
    input  wire                    s_arvalid,
    output wire                    s_arready,
    input  wire [ADDR_WIDTH-1:0]   s_araddr,
    output wire                    s_rvalid,
    input  wire                    s_rready,
    output wire [AXI_DW-1:0]      s_rdata,
    output wire [1:0]              s_rresp,
    output wire signed [DATA_WIDTH-1:0] pixel_out,
    output wire signed [DATA_WIDTH-1:0] weight_out,
    output wire valid_out,
    input  wire done_in,
    input  wire [AXI_DW-1:0] result_in
);
    axi4lite_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .AXI_DW(AXI_DW)
    ) u_slave (.*);
endmodule
