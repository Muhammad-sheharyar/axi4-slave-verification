//-------------------------------------------------------------------------
//  axi_slave verification - Stage 1
//  generator.sv
//-------------------------------------------------------------------------
//  Identical pattern to the adder testbench's generator: create and
//  randomize 'repeat_count' transactions and push them into a mailbox.
//  No driver/interface/DUT is connected at this stage -- this file is
//  brought up standalone first (see gen_only_test.sv).
//-------------------------------------------------------------------------
class generator;

  //declaring transaction class handle
  rand transaction trans;

  //repeat count, to specify number of items to generate
  int  repeat_count;

  //mailbox, to send the transaction packet to driver (later stage)
  mailbox gen2driv;

  //event, to indicate the end of transaction generation
  event ended;

  //constructor
  function new(mailbox gen2driv);
    this.gen2driv = gen2driv;
  endfunction

  //main task: generates (create + randomize) repeat_count transactions
  task main();
    repeat (repeat_count) begin
      trans = new();
      if (!trans.randomize())
        $fatal("Gen:: trans randomization failed");
      trans.display("[ Generator ]");
      gen2driv.put(trans);
    end
    -> ended;  //triggering indicates the end of generation
  endtask

endclass
