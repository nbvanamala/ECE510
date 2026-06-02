`timescale 1ns/1ps
// tb_top.sv — M4 final testbench
// Runs 3 measured patch invocations (weights loaded once, pixels re-streamed 3x).
// Prints $time markers so every cycle number is directly traceable to this log.
module tb_top;
reg clk=0,rst=1;
reg s_awvalid=0;wire s_awready;reg[31:0]s_awaddr=0;
reg s_wvalid=0;wire s_wready;reg[31:0]s_wdata=0;reg[3:0]s_wstrb=4'hF;
wire s_bvalid;reg s_bready=0;wire[1:0]s_bresp;
reg s_arvalid=0;wire s_arready;reg[31:0]s_araddr=0;
wire s_rvalid;reg s_rready=0;wire[31:0]s_rdata;wire[1:0]s_rresp;
wire[127:0]result_out;
top #(.NUM_PE(4),.DATA_WIDTH(8),.ACCUM_WIDTH(32),.KERNEL_SIZE(9),
      .ADDR_WIDTH(32),.AXI_DW(32)) dut(
  .clk(clk),.rst(rst),
  .s_awvalid(s_awvalid),.s_awready(s_awready),.s_awaddr(s_awaddr),
  .s_wvalid(s_wvalid),.s_wready(s_wready),.s_wdata(s_wdata),.s_wstrb(s_wstrb),
  .s_bvalid(s_bvalid),.s_bready(s_bready),.s_bresp(s_bresp),
  .s_arvalid(s_arvalid),.s_arready(s_arready),.s_araddr(s_araddr),
  .s_rvalid(s_rvalid),.s_rready(s_rready),.s_rdata(s_rdata),.s_rresp(s_rresp),
  .result_out(result_out));
always #5 clk=~clk;
initial begin $dumpfile("final_waveform.vcd");$dumpvars(0,tb_top);end

// ── AXI write driver ──────────────────────────────────────────────────────
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
    endcase
  end
end
task axi_write;input[31:0]addr,data;integer t;begin
  @(posedge clk);#1;wr_addr=addr;wr_data=data;wr_req=1;
  @(posedge clk);#1;wr_req=0;
  t=0;while(!wr_done&&t<500)begin @(posedge clk);#1;t=t+1;end
end endtask

// ── AXI read driver ───────────────────────────────────────────────────────
reg[31:0]rd_addr,rd_data_out;reg rd_req=0,rd_done=0;reg[1:0]rd_st=0;
always @(posedge clk) begin
  if(rst)begin rd_st<=0;s_arvalid<=0;s_rready<=0;rd_done<=0;end
  else begin rd_done<=0;
    case(rd_st)
      2'd0:if(rd_req)begin s_arvalid<=1;s_araddr<=rd_addr;rd_st<=1;end
      2'd1:if(s_arvalid&&s_arready)begin s_arvalid<=0;s_rready<=1;rd_st<=2;end
      2'd2:if(s_rvalid&&s_rready)begin rd_data_out<=s_rdata;s_rready<=0;rd_done<=1;rd_st<=0;end
    endcase
  end
end
task axi_read;input[31:0]addr;output[31:0]rdata;integer t;begin
  @(posedge clk);#1;rd_addr=addr;rd_req=1;
  @(posedge clk);#1;rd_req=0;
  t=0;while(!rd_done&&t<500)begin @(posedge clk);#1;t=t+1;end
  rdata=rd_data_out;
end endtask

// ── Register addresses ────────────────────────────────────────────────────
localparam ADDR_PIXEL_IN =32'h00, ADDR_WEIGHT_IN=32'h04, ADDR_CTRL=32'h08;
localparam ADDR_RESULT0  =32'h10, ADDR_RESULT1  =32'h14;
localparam ADDR_RESULT2  =32'h18, ADDR_RESULT3  =32'h1C, ADDR_DONE=32'h20;

// ── Test data ─────────────────────────────────────────────────────────────
reg signed[31:0]expected[0:3];
reg [7:0]pixel_tap[0:8];
integer i,fail_count,poll_count,run_iter;
reg [31:0]rval;
reg signed[31:0]got;

// ── Timing measurement ────────────────────────────────────────────────────
// $time returns ns (timescale 1ns/1ps). Clock period = 10 ns.
// cycles = elapsed_ns / 10
reg [63:0]t_weight_done, t_measure_start, t_measure_end;
integer total_ns, total_cycles, cycles_per_patch;

// ── Main test sequence ────────────────────────────────────────────────────
initial begin
  fail_count=0;
  expected[0]=32'sd135; expected[1]=32'sd315;
  expected[2]=-32'sd90; expected[3]=32'sd225;
  pixel_tap[0]=8'd1; pixel_tap[1]=8'd2; pixel_tap[2]=8'd3;
  pixel_tap[3]=8'd4; pixel_tap[4]=8'd5; pixel_tap[5]=8'd6;
  pixel_tap[6]=8'd7; pixel_tap[7]=8'd8; pixel_tap[8]=8'd9;

  // ── Reset ──────────────────────────────────────────────────────────────
  $display("[RESET] Asserting reset for 5 clock cycles");
  repeat(5)@(posedge clk); rst=0; repeat(3)@(posedge clk);
  $display("[RESET] Reset deasserted at t=%0d ns", $time);

  // ── Weight load (done ONCE — amortized over all patches) ───────────────
  $display("[WEIGHT LOAD] Loading 4 PE weights (one-time cost)");
  axi_write(ADDR_WEIGHT_IN,32'd3);  $display("[WEIGHT LOAD] PE0 weight= 3");
  axi_write(ADDR_WEIGHT_IN,32'd7);  $display("[WEIGHT LOAD] PE1 weight= 7");
  axi_write(ADDR_WEIGHT_IN,32'hFE); $display("[WEIGHT LOAD] PE2 weight=-2 (0xFE INT8)");
  axi_write(ADDR_WEIGHT_IN,32'd5);  $display("[WEIGHT LOAD] PE3 weight= 5");
  repeat(2)@(posedge clk);
  t_weight_done = $time;
  $display("[WEIGHT LOAD] Complete at t=%0d ns", t_weight_done);

  // ── 3-invocation measurement ───────────────────────────────────────────
  // Weights stay loaded. Each invocation: stream 9 pixels → poll DONE → read results.
  // The conv_pe accumulator self-resets after tap 9 (tap_count wraps to 0).
  // Reading ADDR_DONE clears the sticky done flag for the next run.
  $display("[MEASURE] Starting 3-invocation timing measurement");
  t_measure_start = $time;

  for(run_iter=1; run_iter<=3; run_iter=run_iter+1) begin
    $display("[RUN %0d] --- Pixel stream start t=%0d ns ---", run_iter, $time);

    // Stream 9 pixel taps via PIXEL_IN + CTRL
    for(i=0;i<9;i=i+1) begin
      axi_write(ADDR_PIXEL_IN,{24'd0,pixel_tap[i]});
      axi_write(ADDR_CTRL,32'h1);
      $display("[RUN %0d] Tap %0d: pixel=%0d at t=%0d ns",
               run_iter, i, pixel_tap[i], $time);
    end

    // Poll DONE register until computation complete
    $display("[RUN %0d] Polling DONE (0x20)", run_iter);
    rval=0; poll_count=0;
    while(rval[0]!==1'b1 && poll_count<200) begin
      axi_read(ADDR_DONE,rval); poll_count=poll_count+1;
    end
    if(rval[0]!==1'b1) begin
      $display("FAIL: Run %0d DONE timeout at t=%0d ns", run_iter, $time);
      $finish;
    end
    $display("[RUN %0d] DONE=1 after %0d poll(s) at t=%0d ns",
             run_iter, poll_count, $time);

    // Read back all 4 PE results and verify
    axi_read(ADDR_RESULT0,rval); got=$signed(rval);
    $display("[RUN %0d] PE0: got=%0d expected=%0d %s",
             run_iter,got,expected[0],(got===expected[0])?"OK":"MISMATCH");
    if(got!==expected[0]) fail_count=fail_count+1;

    axi_read(ADDR_RESULT1,rval); got=$signed(rval);
    $display("[RUN %0d] PE1: got=%0d expected=%0d %s",
             run_iter,got,expected[1],(got===expected[1])?"OK":"MISMATCH");
    if(got!==expected[1]) fail_count=fail_count+1;

    axi_read(ADDR_RESULT2,rval); got=$signed(rval);
    $display("[RUN %0d] PE2: got=%0d expected=%0d %s",
             run_iter,got,expected[2],(got===expected[2])?"OK":"MISMATCH");
    if(got!==expected[2]) fail_count=fail_count+1;

    axi_read(ADDR_RESULT3,rval); got=$signed(rval);
    $display("[RUN %0d] PE3: got=%0d expected=%0d %s",
             run_iter,got,expected[3],(got===expected[3])?"OK":"MISMATCH");
    if(got!==expected[3]) fail_count=fail_count+1;

    $display("[RUN %0d] --- Complete at t=%0d ns ---", run_iter, $time);
  end // for run_iter

  t_measure_end = $time;

  // ── Cycle accounting ───────────────────────────────────────────────────
  total_ns     = t_measure_end - t_measure_start;
  total_cycles = total_ns / 10;
  cycles_per_patch = total_cycles / 3;

  $display("");
  $display("=== TIMING SUMMARY ===");
  $display("Clock period          : 10 ns (100 MHz)");
  $display("Measurement start     : t=%0d ns", t_measure_start);
  $display("Measurement end       : t=%0d ns", t_measure_end);
  $display("Elapsed (3 patches)   : %0d ns", total_ns);
  $display("Total clock cycles    : %0d cycles  (= %0d ns / 10 ns)", total_cycles, total_ns);
  $display("Cycles per patch      : %0d cycles  (= %0d / 3)", cycles_per_patch, total_cycles);
  $display("Time per patch        : %0d ns", cycles_per_patch * 10);
  $display("======================");
  $display("");

  repeat(5)@(posedge clk);
  if(fail_count==0) $display("PASS");
  else              $display("FAIL (%0d errors)", fail_count);
  $finish;
end

initial begin #10000000; $display("FAIL (timeout)"); $finish; end
endmodule
