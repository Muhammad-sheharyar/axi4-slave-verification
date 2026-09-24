//-------------------------------------------------------------------------
//  axi_slave verification - Stage 2
//  test.sv
//-------------------------------------------------------------------------
`include "environment.sv"

program test(axi_if i_intf);

  environment env;

  initial begin
    env = new(i_intf);
    env.gen.repeat_count = 20;
    env.run();
  end

  // Safety timeout -- hang se bachne ke liye
  initial begin
    #100_000;
    $display("[ TEST ] TIMEOUT -- 10us tak simulation khatam nahi hui.");
    $display("[ TEST ] no_transactions = %0d", env.driv.no_transactions);
    $finish;
  end

endprogram