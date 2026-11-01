// DE10-Standard demonstration wrapper for the CNN-to-systolic datapath.
// SW[1]=0 selects the committed normal demo window; SW[1]=1 selects outer.
// A rising edge on SW[0] launches one inference. KEY[0] is active-low reset.
module de10_systolic_cnn_top (
  input  logic CLOCK_50,
  input  logic [0:0] KEY,
  input  logic [1:0] SW,
  output logic [9:0] LEDR
);
  logic [1:0] reset_release_sync;
  logic rst_n_sync;
  logic sw0_meta, sw0_sync, sw1_meta, sw1_sync, sw0_d;
  logic [25:0] heartbeat;

  typedef enum logic [2:0] {IDLE, LAUNCH, FEED, WAIT_RESULT} board_state_t;
  board_state_t board_state;

  logic cnn_start, cnn_done, cnn_ready, cnn_window_valid;
  logic signed [7:0] cnn_window_sample;
  logic cnn_logits_valid, cnn_overflow_seen;
  logic [31:0] cnn_cycle_count;
  logic signed [31:0] logits0, logits1, logits2, logits3;
  logic [1:0] predicted_class;
  logic [8:0] feed_index;
  logic mode_latched, done_latched;

  logic signed [7:0] demo_inputs [0:511];
  logic signed [7:0] c1_w [0:39];
  logic signed [7:0] c2_w [0:191];
  logic signed [7:0] fc_w [0:63];
  logic signed [31:0] c1_b [0:7];
  logic signed [31:0] c2_b [0:7];
  logic signed [31:0] fc_b [0:7];

  logic signed [319:0] c1w_flat;
  logic signed [255:0] c1b_flat;
  logic signed [1535:0] c2w_flat;
  logic signed [255:0] c2b_flat;
  logic signed [255:0] fcw_flat;
  logic signed [127:0] fcb_flat;

  integer i, k, oc;
  integer best_logit;
  logic [2:0] board_state_code;

  initial begin
    $readmemh("../de10_standard_hw/model_data/demo_inputs.hex", demo_inputs);
    $readmemh("../de10_standard_hw/model_data/conv1_weights.hex", c1_w);
    $readmemh("../de10_standard_hw/model_data/conv1_bias.hex", c1_b);
    $readmemh("../de10_standard_hw/model_data/conv2_weights.hex", c2_w);
    $readmemh("../de10_standard_hw/model_data/conv2_bias.hex", c2_b);
    $readmemh("../de10_standard_hw/model_data/classifier_weights.hex", fc_w);
    $readmemh("../de10_standard_hw/model_data/classifier_bias.hex", fc_b);
  end

  always_comb begin
    for (i=0;i<40;i=i+1)
      c1w_flat[i*8 +: 8] = c1_w[i];
    for (i=0;i<8;i=i+1) begin
      c1b_flat[i*32 +: 32] = c1_b[i];
      c2b_flat[i*32 +: 32] = c2_b[i];
      fcb_flat[i*32 +: 32] = fc_b[i];
    end
    for (i=0;i<192;i=i+1)
      c2w_flat[i*8 +: 8] = c2_w[i];
    fcw_flat = '0;
    for (k=0;k<8;k=k+1)
      for (oc=0;oc<4;oc=oc+1)
        fcw_flat[(k*4+oc)*8 +: 8] = fc_w[k*8+oc];

    cnn_window_valid = (board_state == FEED) && cnn_ready;
    if (mode_latched)
      cnn_window_sample = demo_inputs[256 + feed_index];
    else
      cnn_window_sample = demo_inputs[feed_index];

    best_logit = logits0;
    predicted_class = 2'd0;
    if ($signed(logits1) > best_logit) begin
      best_logit = logits1;
      predicted_class = 2'd1;
    end
    if ($signed(logits2) > best_logit) begin
      best_logit = logits2;
      predicted_class = 2'd2;
    end
    if ($signed(logits3) > best_logit) begin
      predicted_class = 2'd3;
    end

    board_state_code = board_state;
  end

  always_ff @(posedge CLOCK_50 or negedge KEY[0]) begin
    if (!KEY[0])
      reset_release_sync <= 2'b00;
    else
      reset_release_sync <= {reset_release_sync[0],1'b1};
  end
  assign rst_n_sync = reset_release_sync[1];

  always_ff @(posedge CLOCK_50 or negedge rst_n_sync) begin
    if (!rst_n_sync) begin
      sw0_meta <= 1'b0;
      sw0_sync <= 1'b0;
      sw1_meta <= 1'b0;
      sw1_sync <= 1'b0;
      sw0_d <= 1'b0;
      heartbeat <= '0;
    end else begin
      sw0_meta <= SW[0];
      sw0_sync <= sw0_meta;
      sw1_meta <= SW[1];
      sw1_sync <= sw1_meta;
      sw0_d <= sw0_sync;
      heartbeat <= heartbeat + 1'b1;
    end
  end

  always_ff @(posedge CLOCK_50 or negedge rst_n_sync) begin
    if (!rst_n_sync) begin
      board_state <= IDLE;
      cnn_start <= 1'b0;
      feed_index <= '0;
      mode_latched <= 1'b0;
      done_latched <= 1'b0;
    end else begin
      cnn_start <= 1'b0;
      case (board_state)
        IDLE: begin
          if (sw0_sync && !sw0_d) begin
            mode_latched <= sw1_sync;
            feed_index <= '0;
            done_latched <= 1'b0;
            board_state <= LAUNCH;
          end
        end
        LAUNCH: begin
          cnn_start <= 1'b1;
          board_state <= FEED;
        end
        FEED: begin
          if (cnn_window_valid) begin
            if (feed_index == 9'd255)
              board_state <= WAIT_RESULT;
            else
              feed_index <= feed_index + 1'b1;
          end
        end
        WAIT_RESULT: begin
          if (cnn_done) begin
            done_latched <= 1'b1;
            board_state <= IDLE;
          end
        end
        default: board_state <= IDLE;
      endcase
    end
  end

  cnn_inference_top u_cnn (
    .clk(CLOCK_50),
    .rst_n(rst_n_sync),
    .start(cnn_start),
    .done(cnn_done),
    .window_sample(cnn_window_sample),
    .window_valid(cnn_window_valid),
    .window_ready(cnn_ready),
    .conv1_weights_flat(c1w_flat),
    .conv1_bias_flat(c1b_flat),
    .conv2_weights_flat(c2w_flat),
    .conv2_bias_flat(c2b_flat),
    .classifier_weights_flat(fcw_flat),
    .classifier_bias_flat(fcb_flat),
    .logits0(logits0), .logits1(logits1),
    .logits2(logits2), .logits3(logits3),
    .logits_valid(cnn_logits_valid),
    .cycle_count(cnn_cycle_count),
    .overflow_seen(cnn_overflow_seen)
  );

  assign LEDR[0] = heartbeat[25];
  assign LEDR[1] = (board_state != IDLE);
  assign LEDR[2] = done_latched;
  assign LEDR[4:3] = predicted_class;
  assign LEDR[5] = mode_latched;
  assign LEDR[6] = cnn_overflow_seen;
  assign LEDR[9:7] = board_state_code;
endmodule
