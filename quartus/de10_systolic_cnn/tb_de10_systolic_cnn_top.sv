`timescale 1ns/1ps
module tb_de10_systolic_cnn_top;
  logic CLOCK_50 = 1'b0;
  logic [0:0] KEY = 1'b0;
  logic [1:0] SW = 2'b00;
  logic [9:0] LEDR;
  integer timeout_cycles;

  always #10 CLOCK_50 = ~CLOCK_50;

  de10_systolic_cnn_top dut (
    .CLOCK_50(CLOCK_50),
    .KEY(KEY),
    .SW(SW),
    .LEDR(LEDR)
  );

  task automatic wait_done(input integer max_cycles, input logic [1:0] expected_class,
                           input logic expected_mode);
    begin
      timeout_cycles=0;
      while (LEDR[2] !== 1'b1 && timeout_cycles < max_cycles) begin
        @(negedge CLOCK_50);
        timeout_cycles=timeout_cycles+1;
      end
      if (LEDR[2] !== 1'b1)
        $fatal(1,"DE10_WRAPPER_TIMEOUT mode=%0d state=%0d",expected_mode,LEDR[9:7]);
      if (LEDR[4:3] !== expected_class)
        $fatal(1,"DE10_WRAPPER_CLASS_MISMATCH mode=%0d got=%0d expected=%0d",
               expected_mode,LEDR[4:3],expected_class);
      if (LEDR[5] !== expected_mode)
        $fatal(1,"DE10_WRAPPER_MODE_MISMATCH got=%0d expected=%0d",LEDR[5],expected_mode);
      if (LEDR[6] !== 1'b0)
        $fatal(1,"DE10_WRAPPER_OVERFLOW mode=%0d",expected_mode);
      $display("DE10_WRAPPER_CASE_PASS mode=%0d class=%0d cycles=%0d",
               expected_mode,LEDR[4:3],timeout_cycles);
    end
  endtask

  initial begin
    repeat(5) @(negedge CLOCK_50);
    KEY[0]=1'b1;
    repeat(5) @(negedge CLOCK_50);

    // Normal sample: SW[1]=0; rising edge on SW[0] launches inference.
    SW[1]=1'b0;
    SW[0]=1'b1;
    wait_done(100000,2'd0,1'b0);

    // Release SW[0], allow synchronizer/edge detector to re-arm.
    SW[0]=1'b0;
    repeat(8) @(negedge CLOCK_50);

    // Outer sample: SW[1]=1.
    SW[1]=1'b1;
    SW[0]=1'b1;
    // The prior done LED is cleared when the new request is accepted.
    timeout_cycles=0;
    while (LEDR[2] !== 1'b0 && timeout_cycles < 20) begin
      @(negedge CLOCK_50);
      timeout_cycles=timeout_cycles+1;
    end
    if (LEDR[2] !== 1'b0)
      $fatal(1,"DE10_WRAPPER_DID_NOT_CLEAR_DONE_FOR_SECOND_RUN");
    wait_done(100000,2'd3,1'b1);

    $display("DE10_SYSTOLIC_CNN_WRAPPER_TEST_PASS");
    $finish;
  end
endmodule
