//// -------------------------------------------------------------------------
 //// axi_slave verification - Stage 3
 //// environment.sv
//// -------------------------------------------------------------------------
`include "transaction.sv"
`include "generator.sv"
`include "driver.sv"
`include "monitor.sv"
`include "scoreboard.sv"

class environment;

  generator  gen;
  driver     driv;
  monitor    mon;
  scoreboard scb;

  mailbox gen2driv;
  mailbox mon2scb;

  virtual axi_if vif;

  function new(virtual axi_if vif);
    this.vif = vif;

    gen2driv = new();
    mon2scb  = new();

    gen  = new(gen2driv);
    driv = new(vif, gen2driv);
    mon  = new(vif, mon2scb);
    scb  = new(vif, mon2scb);
  endfunction

  task pre_test();
    driv.reset();
  endtask

  task test();
    fork
      gen.main();
      driv.main();
      mon.run();
      scb.run();
    join_none
  endtask

  task post_test();
    wait (gen.repeat_count == driv.no_transactions);
    #500;                  // scoreboard last txn process kar le
    scb.check_memory();
    $display("[ ENV ] All %0d transactions completed.", driv.no_transactions);
    
	// Stage 4 -- read back verification
    read_and_check();
  endtask

  //=========================================================================
  //  Stage 4: Simple read-back verification (single-beat reads)
  //=========================================================================
  task read_and_check();
    int errors = 0;
    bit [31:0] rd_data;

    $display("");
    $display("===============================================");
    $display("[ ENV ] READ-BACK CHECK START");
    $display("===============================================");

    for (int addr = 0; addr < 128; addr++) begin
      // -------- Drive AR (single beat, 1 byte) --------
      @(posedge vif.clk);
      vif.arvalid <= 1;
      vif.arid    <= 4'd0;
      vif.araddr  <= addr;
      vif.arlen   <= 4'd0;    // 1 beat
      vif.arsize  <= 3'd0;    // 1 byte
      vif.arburst <= 2'b01;   // INCR
      vif.rready  <= 1;

      // -------- AR handshake --------
      do @(posedge vif.clk); while (!vif.arready);
      vif.arvalid <= 0;

      // -------- R beat capture --------
      do @(posedge vif.clk); while (!vif.rvalid);
      rd_data = vif.rdata;

      // -------- Compare with reference memory --------
      if (rd_data[7:0] !== scb.ref_mem[addr]) begin
        $display("[ ENV ] RD MISMATCH addr=%0d exp=0x%02h got=0x%02h",
                 addr, scb.ref_mem[addr], rd_data[7:0]);
        errors++;
      end
    end

    vif.rready <= 0;

    if (errors == 0)
      $display("[ ENV ] READ-BACK CHECK PASSED -- all 128 bytes match!");
    else
      $display("[ ENV ] READ-BACK CHECK FAILED -- %0d mismatches", errors);
    $display("===============================================");
  endtask

  task run;
    pre_test();
    test();
    post_test();
    $display("[ ENV ] Simulation finished cleanly.");
	
	//---------------- Functional Coverage Report ----------------
    $display("");
    $display("===============================================");
    $display("[ COV ] FUNCTIONAL COVERAGE REPORT");
    $display("===============================================");
    $display("[ COV ] cg_aw overall:       %.2f%%", mon.cg_aw.get_coverage());
    $display("[ COV ]   burst type:        %.2f%%", mon.cg_aw.cp_burst.get_coverage());
    $display("[ COV ]   length:            %.2f%%", mon.cg_aw.cp_len.get_coverage());
    $display("[ COV ]   size:              %.2f%%", mon.cg_aw.cp_size.get_coverage());
    $display("[ COV ]   cross burst x len: %.2f%%", mon.cg_aw.cx_burst_len.get_coverage());
    $display("[ COV ]   cross burst x size:%.2f%%", mon.cg_aw.cx_burst_size.get_coverage());
    $display("===============================================");
	
    $finish;
  endtask

endclass
