//-------------------------------------------------------------------------
//  axi_slave verification - Stage 2
//  driver.sv
//-------------------------------------------------------------------------
//  Gets a write-burst transaction from the generator and drives it onto
//  the AW/W/B pins of axi_slave, one AXI handshake at a time.
//
//  IMPORTANT DUT QUIRK (found by reading axi_slave.sv):
//  the write-data FSM reads "awaddr" and "awsize" LIVE off the bus on
//  every beat (not a value it latched once at the AW handshake), and
//  the B-response logic does the same. So awaddr/awlen/awsize/awburst
//  must stay driven and stable for the WHOLE burst, not just during the
//  AW handshake. This driver holds them until the transaction is fully
//  complete (after the B response), which satisfies that requirement
//  and is also safe/legal AXI behavior.
//-------------------------------------------------------------------------
class driver;

  int no_transactions;
  virtual axi_if vif;
  mailbox gen2driv;

  function new(virtual axi_if vif, mailbox gen2driv);
    this.vif      = vif;
    this.gen2driv = gen2driv;
    no_transactions = 0;
  endfunction

  task reset;
    wait(!vif.resetn);
    $display("[ DRIVER ] ----- Reset Started -----");
    vif.drv_cb.awvalid <= 0;
    vif.drv_cb.awid    <= 0;
    vif.drv_cb.awaddr  <= 0;
    vif.drv_cb.awlen   <= 0;
    vif.drv_cb.awsize  <= 0;
    vif.drv_cb.awburst <= 0;
    vif.drv_cb.wvalid  <= 0;
    vif.drv_cb.wid     <= 0;
    vif.drv_cb.wdata   <= 0;
    vif.drv_cb.wstrb   <= 0;
    vif.drv_cb.wlast   <= 0;
    vif.drv_cb.bready  <= 0;
    wait(vif.resetn);
    $display("[ DRIVER ] ----- Reset Ended   -----");
  endtask

 task main;
  forever begin
    transaction trans;
    gen2driv.get(trans);
    @(posedge vif.clk);

    $display("");
    $display("[DRV] ===== NEW TXN=%0d: id=%0d addr=%0d len=%0d =====",
             no_transactions+1, trans.awid, trans.awaddr, trans.awlen);

    // ============================================
    // AW aur W parallel
    // ============================================
    fork
      // -------- AW --------
      begin
        vif.drv_cb.awvalid <= 1;
        vif.drv_cb.awid    <= trans.awid;
        vif.drv_cb.awaddr  <= trans.awaddr;
        vif.drv_cb.awlen   <= trans.awlen;
        vif.drv_cb.awsize  <= trans.awsize;
        vif.drv_cb.awburst <= trans.awburst;
        do @(posedge vif.clk); while (!vif.drv_cb.awready);
        $display("[DRV-AW] t=%0t: AW HANDSHAKE DONE", $time);
        vif.drv_cb.awvalid <= 0;
      end

      // -------- W --------
      begin
        for (int i = 0; i <= trans.awlen; i++) begin
          vif.drv_cb.wvalid <= 1;
          vif.drv_cb.wid    <= trans.awid;
          vif.drv_cb.wdata  <= trans.wdata[i];
          vif.drv_cb.wstrb  <= trans.wstrb[i];
          vif.drv_cb.wlast  <= (i == trans.awlen);
          do @(posedge vif.clk); while (!vif.drv_cb.wready);
          $display("[DRV-W ] t=%0t:   beat %0d ACCEPTED", $time, i);
        end
        vif.drv_cb.wvalid <= 0;
        vif.drv_cb.wlast  <= 0;
        vif.drv_cb.wid    <= 0;
        $display("[DRV-W ] t=%0t: all beats done", $time);
      end
    join                          // ← No semicolon after join

    // ============================================
    // B channel -- Outside the fork
    // ============================================
    vif.drv_cb.bready <= 1;	
	// 2 cycle wait -- let propagate bready
	@(posedge vif.clk);
	@(posedge vif.clk);
	$display("[DRV-B ] t=%0t: bready=%b bvalid=%b", $time, vif.bready, vif.bvalid);
	
    // wait for bvalid
    while (!vif.drv_cb.bvalid) @(posedge vif.clk);

    // $display("[DRV-B ] t=%0t: B RESPONSE: bid=%0d bresp=%0d",
             // $time, vif.bid, vif.bresp);
    trans.bid   = vif.bid;
    trans.bresp = vif.bresp;

    @(posedge vif.clk);
    vif.drv_cb.bready <= 0;

    // idle
    vif.drv_cb.awaddr  <= 0;
    vif.drv_cb.awlen   <= 0;
    vif.drv_cb.awsize  <= 0;
    vif.drv_cb.awburst <= 0;
    vif.drv_cb.awid    <= 0;

    trans.display("[ Driver ]");
    no_transactions++;
    $display("[DRV] ===== TXN DONE (count=%0d) =====", no_transactions);
  end
endtask

endclass