//-------------------------------------------------------------------------
//  axi_slave verification - Stage 3
//  scoreboard.sv
//-------------------------------------------------------------------------
//  According to AXI Spec Reference memory do maintain
//  At the end of the simulation it compare with the DUT memory.
//-------------------------------------------------------------------------
class scoreboard;

  virtual axi_if vif;
  mailbox        mon2scb;

  bit [7:0] ref_mem [0:127];   // Reference memory
  int       txn_count;

  function new(virtual axi_if vif, mailbox mon2scb);
    this.vif     = vif;
    this.mon2scb = mon2scb;
    txn_count    = 0;
    // Same initialization with DUT
    foreach (ref_mem[i]) ref_mem[i] = 8'h0C;
  endfunction

  //-------------------------------------------------------------------------
  //  Reference model: According to spec address + memory update
  //-------------------------------------------------------------------------
  function void update_ref_mem(transaction trans);
    bit [31:0] cur_addr;
    bit [31:0] bytes_per_beat;
    bit [31:0] window;
    bit [31:0] wrap_base;
    bit [31:0] wrap_upper;

    bytes_per_beat = 1 << trans.awsize;
    cur_addr       = trans.awaddr;

    // Calculate the boundaries for WRAP
    if (trans.awburst == 2'b10) begin
      window     = bytes_per_beat * (trans.awlen + 1);
      wrap_base  = (cur_addr / window) * window;
      wrap_upper = wrap_base + window;
    end
    for (int i = 0; i <= trans.awlen; i++) begin
      for (int b = 0; b < 4; b++) begin
        if (trans.wstrb[i][b] && (cur_addr + b < 128)) begin
          ref_mem[cur_addr + b] = trans.wdata[i][8*b +: 8];
          // $display("[SCB-REF]     byte %0d -> mem[%0d] = 0x%02h",
                   // b, cur_addr + b, trans.wdata[i][8*b +: 8]);
        end
    end
      // Address calculation (AXI spec)
      case (trans.awburst)
        2'b00: ; // FIXED -- same address
        2'b01: cur_addr = cur_addr + bytes_per_beat;  // INCR
        2'b10: begin // WRAP
          cur_addr = cur_addr + bytes_per_beat;
          if (cur_addr >= wrap_upper) cur_addr = wrap_base;
        end
      endcase
    end
  endfunction

  //-------------------------------------------------------------------------
  //  Main loop: receive transaction, do update reference memory
  //-------------------------------------------------------------------------
  task run();
    transaction trans;
    forever begin
      mon2scb.get(trans);
      txn_count++;

      if (trans.bresp != 2'b00) begin
        $display("[SCB] WARNING: Transaction %0d has bresp=%0d (not OKAY)",
                 txn_count, trans.bresp);
      end
      update_ref_mem(trans);
    end
  endtask

  //-------------------------------------------------------------------------
  //  Final check: DUT memory vs reference memory
  //-------------------------------------------------------------------------
  function void check_memory();
    int errors = 0;
    $display("");
    $display("===============================================");
    $display("[SCB] MEMORY CHECK START (txn_count=%0d)", txn_count);
    $display("===============================================");

    for (int i = 0; i < 128; i++) begin
      if (ref_mem[i] !== testbench_top.DUT.mem[i]) begin
        $display("[SCB] MISMATCH addr=%0d: ref=0x%02h dut=0x%02h",
                 i, ref_mem[i], testbench_top.DUT.mem[i]);
        errors++;
      end
    end

    if (errors == 0)
      $display("[SCB] MEMORY CHECK PASSED -- all 128 bytes match!");
    else
      $display("[SCB] MEMORY CHECK FAILED -- %0d mismatches", errors);

    $display("===============================================");
  endfunction

endclass