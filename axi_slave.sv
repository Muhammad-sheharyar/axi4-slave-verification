//=========================================================================
//  axi_slave.sv  --  Design Under Test - DUT
//  AXI4-Full Slave: FIXED + WRAP burst support
//  4-bit awlen/arlen, 32-bit data, 128-byte memory
//=========================================================================
module axi_slave(
  input  logic        clk,
  input  logic        resetn,

  //------------------- AW --------------------
  input  logic        awvalid,
  output logic        awready,
  input  logic [3:0]  awid,
  input  logic [31:0] awaddr,
  input  logic [3:0]  awlen,
  input  logic [2:0]  awsize,
  input  logic [1:0]  awburst,

  //-------------------- W --------------------
  input  logic        wvalid,
  output logic        wready,
  input  logic [3:0]  wid,
  input  logic [31:0] wdata,
  input  logic [3:0]  wstrb,
  input  logic        wlast,

  //-------------------- B --------------------
  input  logic        bready,
  output logic        bvalid,
  output logic [3:0]  bid,
  output logic [1:0]  bresp,

  //------------------- AR ---------------------
  input  logic        arvalid,
  output logic        arready,
  input  logic [3:0]  arid,
  input  logic [31:0] araddr,
  input  logic [3:0]  arlen,
  input  logic [2:0]  arsize,
  input  logic [1:0]  arburst,

  //-------------------- R ---------------------
  input  logic        rready,
  output logic        rvalid,
  output logic [3:0]  rid,
  output logic [31:0] rdata,
  output logic [1:0]  rresp,
  output logic        rlast
);

  //------------------ Memory ------------------
  logic [7:0] mem [0:127];
   integer k;

  //---------------- FSM states ----------------
  typedef enum logic [2:0] {W_IDLE=0, W_DATA=1, W_RESP=2} wstate_e;
  typedef enum logic [1:0] {B_IDLE=0, B_VALID=1} bstate_e;

  wstate_e wstate;
  bstate_e bstate;

  //---------------- Latched AW ----------------
  logic [3:0]  awid_lat;
  logic [31:0] awaddr_lat;
  logic [3:0]  awlen_lat;
  logic [2:0]  awsize_lat;
  logic [1:0]  awburst_lat;

  //---------------- W counters ----------------
  logic [4:0]  wbeat_count;    // 0..16
  logic [31:0] wcur_addr;
  logic [31:0] wwrap_base;

  //-------------- Response regs ---------------
  logic [3:0]  bid_lat;
  logic [1:0]  bresp_lat;

  //=====================================================================
  //  HELPER: next address
  //=====================================================================
  function automatic logic [31:0] calc_next(
    input logic [31:0] cur,
    input logic [2:0]  size,
    input logic [1:0]  burst,
    input logic [3:0]  len,
    input logic [31:0] wbase
  );
    logic [31:0] bytes, window, upper;
    bytes = (1 << size);
    case (burst)
      2'b00: calc_next = cur;                         // FIXED
      2'b01: calc_next = cur + bytes;                 // INCR
      2'b10: begin                                    // WRAP
        window = bytes * (len + 1);
        upper  = wbase + window;
        if ((cur + bytes) >= upper)
          calc_next = wbase;
        else
          calc_next = cur + bytes;
      end
      default: calc_next = cur;
    endcase
  endfunction

  //=====================================================================
  //  HELPER: wrap base
  //=====================================================================
  function automatic logic [31:0] calc_wrap_base(
    input logic [31:0] addr,
    input logic [2:0]  size,
    input logic [3:0]  len
  );
    logic [31:0] window;
    window = (1 << size) * (len + 1);
    calc_wrap_base = (addr / window) * window;
  endfunction

  //=====================================================================
  //  HELPER: response code
  //=====================================================================
  function automatic logic [1:0] calc_resp(
    input logic [31:0] addr,
    input logic [2:0]  size
  );
    if (addr >= 128)       calc_resp = 2'b11;  // DECERR
    else if (size > 3'b010) calc_resp = 2'b10; // SLVERR
    else                    calc_resp = 2'b00; // OKAY
  endfunction

  //=====================================================================
  //  AW CHANNEL
  //=====================================================================
  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      awready     <= 1'b0;
      awid_lat    <= '0;
      awaddr_lat  <= '0;
      awlen_lat   <= '0;
      awsize_lat  <= '0;
      awburst_lat <= '0;
    end else begin
      // Accept AW when W FSM is idle
      if (awvalid && !awready && (wstate == W_IDLE)) begin
        awready     <= 1'b1;
        awid_lat    <= awid;
        awaddr_lat  <= awaddr;
        awlen_lat   <= awlen;
        awsize_lat  <= awsize;
        awburst_lat <= awburst;
      end else begin
        awready <= 1'b0;
      end
    end
  end

  //=====================================================================
  //  W CHANNEL -- wready COMBINATIONAL (VCS race fix)
  //=====================================================================
  // NOTE: wready is implemented as a combinational signal.
  // If wready is assigned inside an always_ff block using a non-blocking
  // assignment (NBA), VCS evaluates the condition "if (wvalid && wready)"
  // using the PREVIOUS value of wready. As a result, the memory write
  // occurs one clock cycle late, which causes an off-by-one bug in
  // WRAP burst transactions.
  //=====================================================================
    always_comb begin
    if ((wstate == W_DATA) || ((wstate == W_IDLE) && awready))
      wready = 1'b1;
    else
      wready = 1'b0;
    end

  //=====================================================================
  //  W + B FSM (sequential)
  //=====================================================================
  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      wstate       <= W_IDLE;
      wcur_addr    <= '0;
      wwrap_base   <= '0;
      bstate       <= B_IDLE;
      bvalid       <= 1'b0;
      bid          <= '0;
      bresp        <= 2'b00;
      bid_lat      <= '0;
      bresp_lat    <= 2'b00;
      for (k = 0; k < 128; k = k + 1) mem[k] <= 8'h0C;
    end else begin

      //=================== W FSM ===================
      case (wstate)

        //-------------------------------------------------------------
        // W_IDLE -- wait for AW
        //-------------------------------------------------------------
                W_IDLE: begin
          if (awready) begin
            // wwrap_base set
            if (awburst_lat == 2'b10)
              wwrap_base <= calc_wrap_base(awaddr_lat, awsize_lat, awlen_lat);
            else
              wwrap_base <= '0;

            //If WVALID is also High, then accept first beat in this cycle. 
			//By which driver will not goes forward
            if (wvalid && wready) begin
              for (int b = 0; b < 4; b = b + 1) begin
                if (wstrb[b] && ((awaddr_lat + b) < 128)) begin
                  mem[awaddr_lat + b] <= wdata[8*b +: 8];
                end
              end

              if (wlast) begin
                wstate <= W_RESP;
              end else begin
                if (awburst_lat == 2'b10)
                  wcur_addr <= calc_next(awaddr_lat, awsize_lat, awburst_lat,
                                         awlen_lat,
                                         calc_wrap_base(awaddr_lat, awsize_lat, awlen_lat));
                else
                  wcur_addr <= calc_next(awaddr_lat, awsize_lat, awburst_lat,
                                         awlen_lat, '0);
                wstate <= W_DATA;
              end
            end else begin
              // WVALID low -- Only do setup, wait in W_DATA
              wcur_addr <= awaddr_lat;
              wstate <= W_DATA;
            end
          end
        end

        //-------------------------------------------------------------
        // W_DATA -- beats accept
        //-------------------------------------------------------------
        W_DATA: begin
          if (wvalid && wready) begin
            // Memory write
            for (int b = 0; b < 4; b = b + 1) begin
              if (wstrb[b] && ((wcur_addr + b) < 128)) begin
                mem[wcur_addr + b] <= wdata[8*b +: 8];
              end
            end

            // Next address
            wcur_addr <= calc_next(wcur_addr, awsize_lat, awburst_lat,
                                   awlen_lat, wwrap_base);
            // Last beat?
            if (wlast) begin
              wstate <= W_RESP;
            end
          end
        end

        //-------------------------------------------------------------
        // W_RESP -- B response ke liye wait
        //-------------------------------------------------------------
        W_RESP: begin
          if (bstate == B_IDLE)
            wstate <= W_IDLE;
        end
      endcase

      //=================== B FSM ===================
      case (bstate)
        B_IDLE: begin
          bvalid <= 1'b0;
          if (wstate == W_RESP) begin
            bid_lat   <= awid_lat;
            bresp_lat <= calc_resp(awaddr_lat, awsize_lat);
            bstate    <= B_VALID;
          end
        end

        B_VALID: begin
          bvalid <= 1'b1;
          bid    <= bid_lat;
          bresp  <= bresp_lat;
          if (bready && bvalid) begin
            bvalid <= 1'b0;
            bstate <= B_IDLE;
          end
        end
      endcase

    end
  end	


  //=====================================================================
  //  AR + R CHANNEL (simple version)
  //=====================================================================
  logic        arready_r;
  logic [3:0]  arid_lat;
  logic [31:0] araddr_lat;
  logic [3:0]  arlen_lat;
  logic [2:0]  arsize_lat;
  logic [1:0]  arburst_lat;
  logic        rvalid_r;
  logic [31:0] rdata_r;
  logic        rlast_r;
  logic [4:0]  rbeat_count;
  logic [31:0] rcur_addr;

  assign arready = arready_r;
  assign rvalid  = rvalid_r;
  assign rdata   = rdata_r;
  assign rlast   = rlast_r;

  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      arready_r     <= 1'b0;
      arid_lat      <= '0;
      araddr_lat    <= '0;
      arlen_lat     <= '0;
      arsize_lat    <= '0;
      arburst_lat   <= '0;
      rvalid_r      <= 1'b0;
      rdata_r       <= '0;
      rlast_r       <= 1'b0;
      rid           <= '0;
      rresp         <= 2'b00;
      rbeat_count   <= '0;
      rcur_addr     <= '0;
    end else begin
      // AR accept
      if (arvalid && !arready_r && !rvalid_r) begin
        arready_r   <= 1'b1;
        arid_lat    <= arid;
        araddr_lat  <= araddr;
        arlen_lat   <= arlen;
        arsize_lat  <= arsize;
        arburst_lat <= arburst;
      end else begin
        arready_r <= 1'b0;
      end

      // R data
      if (arready_r) begin
        // AR handshake in this cycle -- first beat next cycle
        rcur_addr   <= araddr_lat;
        rbeat_count <= '0;
        rid         <= arid_lat;
        rresp       <= calc_resp(araddr_lat, arsize_lat);
      end else if (rvalid_r && rready) begin
        // Beat accepted
        if (rbeat_count == arlen_lat) begin
          rvalid_r <= 1'b0;
          rlast_r  <= 1'b0;
        end else begin
          rbeat_count <= rbeat_count + 1;
          rcur_addr   <= rcur_addr + (1 << arsize_lat);
        end
      end

      // Drive R
      if (arready_r) begin
        rvalid_r <= 1'b1;
        rdata_r  <= {4{mem[araddr_lat[6:0]]}};
        rlast_r  <= (arlen_lat == 0);
      end else if (rvalid_r && rready && rbeat_count < arlen_lat) begin
        rdata_r <= {4{mem[rcur_addr[6:0]]}};
        rlast_r <= (rbeat_count == arlen_lat);
      end
    end
  end

endmodule