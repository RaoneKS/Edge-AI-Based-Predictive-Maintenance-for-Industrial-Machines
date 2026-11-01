// Independent functional test for the 8x8 CNN systolic tile adapter.
// Expected result for each output column c: sum_k act[k] * weight_rows[k][c].
`timescale 1ns/1ps
import pkg_accelerator::*;

module tb_cnn_systolic_adapter;
  logic clk=0;
  logic rst_n=0;
  logic start=0;
  logic [ACT_WIDTH*ARRAY_ROWS-1:0] act_vector='0;
  logic [WGT_WIDTH*ARRAY_ROWS-1:0] weight_rows [ARRAY_ROWS];
  logic busy, done, any_overflow;
  logic [ACC_WIDTH*ARRAY_COLS-1:0] acc_out_packed;
  integer expected [0:ARRAY_COLS-1];
  integer k,c,trial,timeout_cycles;
  integer signed got;

  always #5 clk=~clk;

  cnn_systolic_adapter dut(
    .clk(clk), .rst_n(rst_n), .start(start),
    .act_vector(act_vector), .weight_rows(weight_rows),
    .busy(busy), .done(done), .acc_out_packed(acc_out_packed),
    .any_overflow(any_overflow)
  );

  task automatic run_trial(input integer seed);
    begin
      act_vector='0;
      for (c=0;c<ARRAY_COLS;c=c+1) expected[c]=0;
      for (k=0;k<ARRAY_ROWS;k=k+1) begin
        // Deterministic signed values, varied between trials.
        act_vector[k*ACT_WIDTH +: ACT_WIDTH] = $signed(((seed*7+k*5)%19)-9);
        weight_rows[k]='0;
        for (c=0;c<ARRAY_COLS;c=c+1) begin
          weight_rows[k][c*WGT_WIDTH +: WGT_WIDTH] =
            $signed(((seed*3+k*7+c*4)%17)-8);
          expected[c] = expected[c]
            + $signed(act_vector[k*ACT_WIDTH +: ACT_WIDTH])
            * $signed(weight_rows[k][c*WGT_WIDTH +: WGT_WIDTH]);
        end
      end

      @(negedge clk); start=1;
      @(negedge clk); start=0;
      timeout_cycles=0;
      while (!done && timeout_cycles<100) begin
        @(negedge clk);
        timeout_cycles=timeout_cycles+1;
      end
      if (!done) $fatal(1,"TIMEOUT trial=%0d busy=%0b",seed,busy);

      for (c=0;c<ARRAY_COLS;c=c+1) begin
        got=$signed(acc_out_packed[c*ACC_WIDTH +: ACC_WIDTH]);
        if (got !== expected[c])
          $fatal(1,"MISMATCH trial=%0d col=%0d got=%0d expected=%0d",
                 seed,c,got,expected[c]);
      end
      if (any_overflow) $fatal(1,"Unexpected overflow trial=%0d",seed);
      $display("ADAPTER_TRIAL_PASS seed=%0d cycles=%0d",seed,timeout_cycles);
      @(negedge clk);
    end
  endtask

  initial begin
    for (k=0;k<ARRAY_ROWS;k=k+1) weight_rows[k]='0;
    repeat(4) @(negedge clk);
    rst_n=1;
    repeat(2) @(negedge clk);
    for (trial=1;trial<=5;trial=trial+1) run_trial(trial);
    $display("CNN_SYSTOLIC_ADAPTER_TEST_PASS trials=5");
    $finish;
  end
endmodule
