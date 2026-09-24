//-------------------------------------------------------------------------
//  axi_slave verification - Stage 2
//  interface.sv
//-------------------------------------------------------------------------
//  Write-side only: AW + W + B channels. AR/R (read side) are tied off
//  at the top level for now -- they belong to the read-back "check"
//  stage that comes later.
//
//  NOTE: axi_slave.sv's reset is active-LOW (resetn), unlike the adder's
//  active-high reset -- driver.sv's reset task is written accordingly.
//-------------------------------------------------------------------------
interface axi_if(input logic clk, resetn);

  //---------------- Write Address Channel (AW) ----------------
  logic        awvalid;
  logic        awready;
  logic [3:0]  awid;
  logic [3:0]  awlen;
  logic [2:0]  awsize;
  logic [31:0] awaddr;
  logic [1:0]  awburst;

  //---------------- Write Data Channel (W) ----------------
  logic        wvalid;
  logic        wready;
  logic [3:0]  wid;
  logic [31:0] wdata;
  logic [3:0]  wstrb;
  logic        wlast;

  //---------------- Write Response Channel (B) ----------------
  logic        bready;
  logic        bvalid;
  logic [3:0]  bid;
  logic [1:0]  bresp;
	
    //---------------- Read Address Channel (AR) ----------------
  logic        arvalid;
  logic        arready;
  logic [3:0]  arid;
  logic [3:0]  arlen;
  logic [2:0]  arsize;
  logic [31:0] araddr;
  logic [1:0]  arburst;

  //---------------- Read Data Channel (R) ----------------
  logic        rready;
  logic        rvalid;
  logic [3:0]  rid;
  logic [31:0] rdata;
  logic [1:0]  rresp;
  logic        rlast;
  
  //---------------- Clocking Block (race-free driving) ----------------
  clocking drv_cb @(posedge clk);
    default input #1step output #1step;
    output awvalid, awid, awaddr, awlen, awsize, awburst;
    output wvalid, wid, wdata, wstrb, wlast;
    output bready;
    input  awready, wready, bvalid, bid, bresp;
  endclocking
  
    //---------------- Monitor Clocking Block (race-free sampling) ----
  clocking mon_cb @(posedge clk);
    default input #1step;
    input awvalid, awready, awid, awaddr, awlen, awsize, awburst;
    input wvalid, wready, wid, wdata, wstrb, wlast;
    input bvalid, bready, bid, bresp;
  endclocking
  
endinterface
