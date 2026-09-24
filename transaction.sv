//-------------------------------------------------------------------------
//  axi_slave verification - Stage 1
//  transaction.sv
//-------------------------------------------------------------------------
//  Scope: WRITE side only (AW + W channels driven; B channel response
//  captured back into the transaction by the driver).
//  Burst modes covered: FIXED (awburst=00) and WRAP (awburst=10),
//  matching the "Wrap + Fixed" scope of the verification spec.
//  AR / R channel fields are intentionally NOT here yet -- those belong
//  to the later read-back "check" transaction stage.
//-------------------------------------------------------------------------
class transaction;

  //---------------------------------------------------------------
  // Write Address Channel (AW) fields
  //---------------------------------------------------------------
  rand bit [3:0]  awid;
  rand bit [31:0] awaddr;
  rand bit [3:0]  awlen;    // encoded length; actual beats = awlen + 1
  rand bit [2:0]  awsize;   // bytes/beat = 2^awsize
  rand bit [1:0]  awburst;  // 00 = FIXED , 10 = WRAP

  //---------------------------------------------------------------
  // Write Data Channel (W) fields -- one entry per beat
  //---------------------------------------------------------------
  rand bit [31:0] wdata[];
  rand bit [3:0]  wstrb[];

  //---------------------------------------------------------------
  // Write Response Channel (B) fields -- NOT randomized.
  // These are captured by the driver after the burst is driven, so
  // we can confirm/print how the DUT responded to this write.
  //---------------------------------------------------------------
  bit [3:0] bid;
  bit [1:0] bresp;

  //---------------------------------------------------------------
  // Helper: mirrors axi_slave.sv's wrap_boundary() function, so that
  // randomization can pick a protocol-legal, boundary-aligned address
  // for WRAP bursts. (Only the awlen/awsize combos the DUT supports.)
  //---------------------------------------------------------------
  function bit [7:0] wrap_boundary(bit [3:0] len, bit [2:0] size);
    int beats;
    case (len)
      4'b0001: beats = 2;   // awlen = 1 -> 2 beats
      4'b0011: beats = 4;   // awlen = 3 -> 4 beats
      4'b0111: beats = 8;   // awlen = 7 -> 8 beats
      4'b1111: beats = 16;  // awlen = 15 -> 16 beats
      default: beats = 1;
    endcase
    return beats * (1 << size);  // boundary = beats * bytes_per_beat
  endfunction

  //---------------------------------------------------------------
  // Constraints
  //---------------------------------------------------------------

  // Scope of this verification effort: FIXED and WRAP bursts only
  constraint c_burst_type {
    awburst inside {2'b00, 2'b10};  //FIXED + WRAP
  }

  // Only the burst lengths the DUT's wrap_boundary() function implements:
  // 2, 4, 8, 16 beats
  constraint c_len {
    awlen inside {4'b0001, 4'b0011, 4'b0111, 4'b1111};
  }

  // Only beat sizes that fit the DUT's 32-bit data path: 1,2,4 bytes/beat
  constraint c_size {
    awsize inside {3'b000, 3'b001, 3'b010};
  }

  // Stay inside the valid mapped memory range (mem[128], addr < 128),
  // with headroom so a full burst / multi-byte beat never walks past 127
  constraint c_addr_range {
    awaddr < 100;
  }

  // AXI protocol rule: WRAP bursts must start on a boundary-aligned address
  constraint c_wrap_align {
    if (awburst == 2'b10)
      awaddr % wrap_boundary(awlen, awsize) == 0;
  }

  // Size the per-beat data/strobe arrays to match the chosen burst length
  constraint c_array_size {
    wdata.size() == awlen + 1;
    wstrb.size() == awlen + 1;
  }

  // Keep at least one byte-lane active every beat (no all-zero, no-op writes)
  constraint c_wstrb_nonzero {
    foreach (wstrb[i]) wstrb[i] != 4'b0000;
  }

  //---------------------------------------------------------------
  // Display
  //---------------------------------------------------------------
  function void display(string name);
    $display("-------------------------------------------------");
    $display("- %s ", name);
    $display("-------------------------------------------------");
    $display("- awid    = %0d", awid);
    $display("- awaddr  = %0d", awaddr);
    $display("- awlen   = %0d  (beats = %0d)", awlen, awlen + 1);
    $display("- awsize  = %0d  (%0d bytes/beat)", awsize, 1 << awsize);
    $display("- awburst = %s", (awburst == 2'b00) ? "FIXED" :
                                (awburst == 2'b10) ? "WRAP"  : "UNKNOWN");
    foreach (wdata[i])
      $display("-   beat[%0d] : wdata = 0x%0h  wstrb = %b", i, wdata[i], wstrb[i]);
    $display("- bid     = %0d", bid);
    $display("- bresp   = %s", (bresp == 2'b00) ? "OKAY"   :
                                (bresp == 2'b10) ? "SLVERR" :
                                (bresp == 2'b11) ? "DECERR" : "?");
    $display("-------------------------------------------------");
  endfunction
 
 //-------------------------------------------------------
function string convert2string();
  string s;
  s = $sformatf("burst=%s addr=%0d len=%0d(beats=%0d) size=%0d(bytes=%0d) id=%0d",
                (awburst == 2'b00) ? "FIXED" :
                (awburst == 2'b10) ? "WRAP"  : "UNKNOWN",
                awaddr, awlen, awlen + 1, awsize, 1 << awsize, awid);
  return s;
endfunction
//-------------------------------------------------------


endclass
