module de10_standard_hw_top (
  input  logic CLOCK_50,
  input  logic [0:0] KEY,
  input  logic [1:0] SW,
  output logic [9:0] LEDR
);

  // Asynchronous reset assertion, synchronous reset release.
  logic [1:0] reset_release_sync;
  logic rst_n_sync;

  always_ff @(posedge CLOCK_50 or negedge KEY[0]) begin
    if (!KEY[0])
      reset_release_sync <= 2'b00;
    else
      reset_release_sync <= {reset_release_sync[0], 1'b1};
  end

  assign rst_n_sync = reset_release_sync[1];

  // Two-stage synchronizers for the physical switch inputs.
  logic sw0_meta, sw0_sync;
  logic sw1_meta, sw1_sync;

  always_ff @(posedge CLOCK_50 or negedge rst_n_sync) begin
    if (!rst_n_sync) begin
      sw0_meta <= 1'b0;
      sw0_sync <= 1'b0;
      sw1_meta <= 1'b0;
      sw1_sync <= 1'b0;
    end else begin
      sw0_meta <= SW[0];
      sw0_sync <= sw0_meta;
      sw1_meta <= SW[1];
      sw1_sync <= sw1_meta;
    end
  end

  logic [25:0] heartbeat;
  logic sw0_d, start_pulse;
  logic busy, done;
  logic done_latched;
  logic mode_latched;
  logic [1:0] predicted_class;
  logic [3:0] state;
  logic [31:0] logits_unused;

  always_ff @(posedge CLOCK_50 or negedge rst_n_sync) begin
    if (!rst_n_sync) begin
      heartbeat    <= '0;
      sw0_d        <= 1'b0;
      start_pulse  <= 1'b0;
      done_latched <= 1'b0;
      mode_latched <= 1'b0;
    end else begin
      heartbeat <= heartbeat + 1'b1;

      // Detect the rising edge of synchronized SW[0].
      start_pulse <= sw0_sync && !sw0_d && !busy;
      sw0_d <= sw0_sync;

      // Capture the mode before the demo consumes start_pulse.
      if (sw0_sync && !sw0_d && !busy)
        mode_latched <= sw1_sync;

      if (start_pulse)
        done_latched <= 1'b0;

      if (done)
        done_latched <= 1'b1;
    end
  end

  bearing_cnn_demo u_demo (
    .clk(CLOCK_50),
    .rst_n(rst_n_sync),
    .start(start_pulse),
    .select_outer(mode_latched),
    .busy(busy),
    .done(done),
    .predicted_class(predicted_class),
    .state(state),
    .logits_out(logits_unused)
  );

  assign LEDR[0]   = heartbeat[25];
  assign LEDR[1]   = busy;
  assign LEDR[2]   = done_latched;
  assign LEDR[5:3] = {mode_latched, predicted_class};
  assign LEDR[9:6] = state;

endmodule
