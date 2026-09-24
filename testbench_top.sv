`timescale 1ns/1ps

//-------------------------------------------------------------------------
//  axi_slave verification - Stage 2
//  testbench_top.sv
//-------------------------------------------------------------------------
//  Top module: connects the interface, the test/environment, and the
//  axi_slave DUT together. This is the file you actually run.
//
//  Compile together with axi_slave.sv, e.g.:
//    vcs -sverilog axi_slave.sv interface.sv testbench_top.sv +vpi -debug_access+all
//    ./simv
//
//  Read-side (AR/R) ports are tied off / left unconnected on purpose --
//  this stage only exercises the write path.
//-------------------------------------------------------------------------
`include "interface.sv"
`include "test.sv"

module testbench_top;

  bit clk;
  bit resetn;

  always #5 clk = ~clk;

  initial begin
    resetn = 0;
    @(negedge clk);
    @(negedge clk);
    resetn = 1;
  end

  axi_if i_intf(clk, resetn);

  test t1(i_intf);

  axi_slave DUT (
    .clk     (i_intf.clk),
    .resetn  (i_intf.resetn),
    .awvalid (i_intf.awvalid),
    .awready (i_intf.awready),
    .awid    (i_intf.awid),
    .awlen   (i_intf.awlen),
    .awsize  (i_intf.awsize),
    .awaddr  (i_intf.awaddr),
    .awburst (i_intf.awburst),
    .wvalid  (i_intf.wvalid),
    .wready  (i_intf.wready),
    .wid     (i_intf.wid),
    .wdata   (i_intf.wdata),
    .wstrb   (i_intf.wstrb),
    .wlast   (i_intf.wlast),
    .bready  (i_intf.bready),
    .bvalid  (i_intf.bvalid),
    .bid     (i_intf.bid),
    .bresp   (i_intf.bresp),
    .arready (i_intf.arready),
    .arid    (i_intf.arid),
    .araddr  (i_intf.araddr),
    .arlen   (i_intf.arlen),
    .arsize  (i_intf.arsize),
    .arburst (i_intf.arburst),
    .arvalid (i_intf.arvalid),
    .rid     (i_intf.rid),
    .rdata   (i_intf.rdata),
    .rresp   (i_intf.rresp),
    .rlast   (i_intf.rlast),
    .rvalid  (i_intf.rvalid),
    .rready  (i_intf.rready)
  );

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, testbench_top);
  end

  initial begin
    $timeformat(-9, 1, " ns", 10);
  end
initial begin

		 // $monitor("t=%0t awv=%b awr=%b wv=%b wr=%b wl=%b bv=%b br=%b wstate=%0d bstate=%0d",
         // $time, i_intf.awvalid, i_intf.awready,
         // i_intf.wvalid, i_intf.wready, i_intf.wlast,
         // i_intf.bvalid, i_intf.bready,
         // DUT.wstate, DUT.bstate);
		 
	
  // $monitor("t=%0t wstate=%0d bstate=%0d wbeat=%0d awlen_lat=%0d wvalid=%b wready=%b wlast=%b bvalid=%b bready=%b",
           // $time, DUT.wstate, DUT.bstate, DUT.wbeat_count,
           // DUT.awlen_lat, i_intf.wvalid, i_intf.wready,
           // i_intf.wlast, i_intf.bvalid, i_intf.bready);
		   
		   // $monitor("t=%0t wstate=%0d bstate=%0d bvalid=%b bready=%b bresp=%0d",
         // $time, DUT.wstate, DUT.bstate, i_intf.bvalid, i_intf.bready, i_intf.bresp);

		 // $monitor("t=%0t wstate=%0d bstate=%0d bvalid=%b bready=%b",
         // $time, DUT.wstate, DUT.bstate, i_intf.bvalid, i_intf.bready);
end

endmodule