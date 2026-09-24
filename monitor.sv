//-------------------------------------------------------------------------
//  axi_slave verification - Stage 3
//  monitor.sv  [FIXED]
//-------------------------------------------------------------------------
class monitor;

  virtual axi_if vif;
  mailbox        mon2scb;
  
  //---------------- Functional Coverage ----------------
  
  bit [1:0] cov_burst;
  bit [3:0] cov_len;
  bit [2:0] cov_size;

  covergroup cg_aw;
    cp_burst: coverpoint cov_burst {
      bins FIXED = {2'b00};
      bins WRAP  = {2'b10};
    }
    cp_len: coverpoint cov_len {
      bins len_2  = {4'b0001};
      bins len_4  = {4'b0011};
      bins len_8  = {4'b0111};
      bins len_16 = {4'b1111};
    }
    cp_size: coverpoint cov_size {
      bins sz_1 = {3'b000};
      bins sz_2 = {3'b001};
      bins sz_4 = {3'b010};
    }
    cx_burst_len:  cross cp_burst, cp_len;
    cx_burst_size: cross cp_burst, cp_size;
  endgroup  
  
  // covergroup cg_aw;
    // cp_burst: coverpoint vif.awburst {
      // bins FIXED = {2'b00};
      // bins WRAP  = {2'b10};
    // }
    // cp_len: coverpoint vif.awlen {
      // bins len_2  = {4'b0001};
      // bins len_4  = {4'b0011};
      // bins len_8  = {4'b0111};
      // bins len_16 = {4'b1111};
    // }
    // cp_size: coverpoint vif.awsize {
      // bins sz_1 = {3'b000};
      // bins sz_2 = {3'b001};
      // bins sz_4 = {3'b010};
    // }
    // cx_burst_len:  cross cp_burst, cp_len;
    // cx_burst_size: cross cp_burst, cp_size;
  // endgroup  

  function new(virtual axi_if vif, mailbox mon2scb);
    this.vif     = vif;
    this.mon2scb = mon2scb;
	cg_aw = new();
  endfunction

  task run();
    forever begin
      transaction trans;
      bit [31:0] wdata_arr [];
      bit [3:0]  wstrb_arr [];
      int        beat;

      //---------------- AW handshake (direct condition) ----------------
      do @(posedge vif.clk);
      while (!(vif.awvalid && vif.awready));

      trans = new();
      trans.awid    = vif.mon_cb.awid;
      trans.awaddr  = vif.mon_cb.awaddr;
      trans.awlen   = vif.mon_cb.awlen;
      trans.awsize  = vif.mon_cb.awsize;
      trans.awburst = vif.mon_cb.awburst;

      $display("[MON   ] t=%0t AW: id=%0d addr=%0d len=%0d burst=%0d",
               $time, trans.awid, trans.awaddr, trans.awlen, trans.awburst);
		cov_burst = trans.awburst;
		cov_len   = trans.awlen;
		cov_size  = trans.awsize;  
		cg_aw.sample();
      //---------------- W beats ----------------
      wdata_arr = new[trans.awlen + 1];
      wstrb_arr = new[trans.awlen + 1];

      beat = 0;
            while (beat <= trans.awlen) begin
        @(posedge vif.clk);
        if (vif.mon_cb.wvalid && vif.mon_cb.wready) begin
          wdata_arr[beat] = vif.mon_cb.wdata;
          wstrb_arr[beat] = vif.mon_cb.wstrb;
          $display("[MON   ] t=%0t: W beat %0d: data=0x%08h strb=%b",
                   $time, beat, vif.mon_cb.wdata, vif.mon_cb.wstrb);
          beat = beat + 1;
        end
      end

      trans.wdata = wdata_arr;
      trans.wstrb = wstrb_arr;

      //---------------- B response ----------------
      do @(posedge vif.clk);
      while (!(vif.mon_cb.bvalid && vif.mon_cb.bready));

      trans.bid   = vif.mon_cb.bid;
      trans.bresp = vif.mon_cb.bresp;

      $display("[MON   ] t=%0t B: bid=%0d bresp=%0d", $time, trans.bid, trans.bresp);
      mon2scb.put(trans);
    end
  endtask

endclass