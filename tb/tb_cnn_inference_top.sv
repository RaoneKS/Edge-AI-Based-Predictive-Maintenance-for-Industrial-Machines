`timescale 1ns/1ps
module tb_cnn_inference_top;
  localparam integer N=512,W=256;
  logic clk,rst_n,start,done,window_valid,window_ready,logits_valid,overflow_seen;
  logic signed [7:0] window_sample;
  logic signed [31:0] logits0,logits1,logits2,logits3;
  logic [31:0] cycle_count;
  logic signed [7:0] c1w_mem[0:63]; logic signed [31:0] c1b_mem[0:7];
  logic signed [7:0] c2w_mem[0:191]; logic signed [31:0] c2b_mem[0:7];
  logic signed [7:0] clfw_mem[0:31]; logic signed [31:0] clfb_mem[0:3];
  logic signed [7:0] in_mem[0:N*W-1]; logic signed [31:0] ref_mem[0:N*4-1];
  logic [7:0] pred_mem[0:N-1]; logic [7:0] label_mem[0:N-1];
  logic [7:0] rtl_pred_mem[0:N-1];
  logic signed [7:0] c1_ref[0:32*256*8-1];
  logic signed [7:0] pool_ref[0:32*128*8-1];
  logic signed [7:0] c2_ref[0:32*128*8-1];
  logic signed [7:0] gap_ref[0:32*8-1];
  logic signed [319:0] c1w_flat; logic signed [255:0] c1b_flat;
  logic signed [1535:0] c2w_flat; logic signed [255:0] c2b_flat;
  logic signed [255:0] clfw_flat; logic signed [127:0] clfb_flat;
  integer i;
  integer sp;
  integer ch;
  integer ref_error_count;
  integer rtl_error_count;
  integer common_error_count;
  integer rtl_only_error_count;
  integer ref_only_error_count;
  integer cycle_count_at_start;
  integer latency_this_window;
  integer latency_sum;
  integer latency_min;
  integer latency_max;
  integer ref_bad;
  integer rtl_bad;
  integer run_windows;
  integer j;
  integer k;
  integer w;
  integer s;
  integer c;
  integer logit_matches;
  integer pred_matches;
  integer err_count;
  integer got_pred;
  integer best_class;
  integer got_value;
  integer reference_value;
  integer expected_pred;
  integer expected_label;
  integer class_total0;
  integer class_total1;
  integer class_total2;
  integer class_total3;
  integer class_correct0;
  integer class_correct1;
  integer class_correct2;
  integer class_correct3;
  integer repeat_logit0;
  integer repeat_logit1;
  integer repeat_logit2;
  integer repeat_logit3;

  cnn_inference_top dut(
    .clk(clk),.rst_n(rst_n),.start(start),.done(done),
    .window_sample(window_sample),.window_valid(window_valid),.window_ready(window_ready),
    .conv1_weights_flat(c1w_flat),.conv1_bias_flat(c1b_flat),
    .conv2_weights_flat(c2w_flat),.conv2_bias_flat(c2b_flat),
    .classifier_weights_flat(clfw_flat),.classifier_bias_flat(clfb_flat),
    .logits0(logits0),.logits1(logits1),.logits2(logits2),.logits3(logits3),
    .logits_valid(logits_valid),.cycle_count(cycle_count),.overflow_seen(overflow_seen));

  
    genvar g;
    generate
      for(g=0;g<8;g=g+1) begin : GEN_C1B
        assign c1b_flat[g*32 +: 32] = c1b_mem[g];
        assign c2b_flat[g*32 +: 32] = c2b_mem[g];
      end
      for(g=0;g<4;g=g+1) begin : GEN_CLFB
        assign clfb_flat[g*32 +: 32] = clfb_mem[g];
      end
    endgenerate
  
    genvar wi;
    generate
      // Authoritative vector files are already flattened in manifest layout [K, output_channel].
      // Keep the flat memory order unchanged; cnn_inference_top indexes the same layout.
      for(wi=0;wi<40;wi=wi+1) begin : GEN_C1W
        assign c1w_flat[wi*8 +: 8] = c1w_mem[wi];
      end
      for(wi=0;wi<192;wi=wi+1) begin : GEN_C2W
        assign c2w_flat[wi*8 +: 8] = c2w_mem[wi];
      end
      for(wi=0;wi<32;wi=wi+1) begin : GEN_CLFW
        assign clfw_flat[wi*8 +: 8] = clfw_mem[wi];
      end
    endgenerate
  
  
  initial begin clk=0;forever #5 clk=~clk;end

  initial begin
    run_windows = N;
    if ($value$plusargs("num_windows=%d", run_windows)) begin
      if (run_windows < 1 || run_windows > N) begin
        $display("ERROR: num_windows must be in range 1..%0d", N);
        $fatal(1);
      end
    end
    $display("CNN_E2E_WINDOWS_REQUESTED=%0d", run_windows);
    $fflush();

    $readmemh("sim/cnn_vectors/input.hex",in_mem);
    $readmemh("sim/cnn_vectors/reference_logits.hex",ref_mem);
    $readmemh("sim/cnn_vectors/reference_predictions.hex",pred_mem);
    $readmemh("sim/cnn_vectors/reference_labels.hex",label_mem);
    $readmemh("sim/cnn_vectors/conv1_weights.hex",c1w_mem);
    $readmemh("sim/cnn_vectors/conv1_bias.hex",c1b_mem);
    $readmemh("sim/cnn_vectors/conv2_weights.hex",c2w_mem);
    $readmemh("sim/cnn_vectors/conv2_bias.hex",c2b_mem);
    $readmemh("sim/cnn_vectors/classifier_weights.hex",clfw_mem);
    $readmemh("sim/cnn_vectors/classifier_bias.hex",clfb_mem);
    $readmemh("sim/cnn_vectors/conv1_first32.hex",c1_ref);
    $readmemh("sim/cnn_vectors/pool_first32.hex",pool_ref);
    $readmemh("sim/cnn_vectors/conv2_first32.hex",c2_ref);
    $readmemh("sim/cnn_vectors/gap_first32.hex",gap_ref);


    class_total0=0;class_total1=0;class_total2=0;class_total3=0;
    class_correct0=0;class_correct1=0;class_correct2=0;class_correct3=0;
    logit_matches=0;pred_matches=0;err_count=0;
    latency_sum=0;latency_min=32'h7fffffff;latency_max=0;
    rst_n=0;start=0;window_valid=0;window_sample=0;
    repeat(5) @(posedge clk); @(negedge clk); rst_n=1;

    for(w=0;w<run_windows;w=w+1) begin
      @(negedge clk);cycle_count_at_start=cycle_count;start=1;@(negedge clk);start=0;
      for(s=0;s<W;s=s+1) begin
        while(!window_ready) @(negedge clk);
        window_sample=in_mem[w*W+s];window_valid=1;@(negedge clk);window_valid=0;
      end
      wait(done);@(posedge clk);
      latency_this_window = cycle_count - cycle_count_at_start;
      latency_sum = latency_sum + latency_this_window;
      if (latency_this_window < latency_min) latency_min = latency_this_window;
      if (latency_this_window > latency_max) latency_max = latency_this_window;

      // Exact stage-by-stage checks for the first 32 windows.
      if (w < 32) begin
        for (sp=0;sp<256;sp=sp+1)
          for (ch=0;ch<8;ch=ch+1)
            if (dut.c1[sp][ch] !== c1_ref[(w*256+sp)*8+ch])
              $fatal(1,"CONV1_MISMATCH w=%0d pos=%0d ch=%0d got=%0d ref=%0d",
                w,sp,ch,$signed(dut.c1[sp][ch]),$signed(c1_ref[(w*256+sp)*8+ch]));
        for (sp=0;sp<128;sp=sp+1)
          for (ch=0;ch<8;ch=ch+1) begin
            if (dut.pool[sp][ch] !== pool_ref[(w*128+sp)*8+ch])
              $fatal(1,"POOL_MISMATCH w=%0d pos=%0d ch=%0d got=%0d ref=%0d",
                w,sp,ch,$signed(dut.pool[sp][ch]),$signed(pool_ref[(w*128+sp)*8+ch]));
            if (dut.c2[sp][ch] !== c2_ref[(w*128+sp)*8+ch])
              $fatal(1,"CONV2_MISMATCH w=%0d pos=%0d ch=%0d got=%0d ref=%0d",
                w,sp,ch,$signed(dut.c2[sp][ch]),$signed(c2_ref[(w*128+sp)*8+ch]));
          end
        for (ch=0;ch<8;ch=ch+1)
          if (dut.gap[ch] !== gap_ref[w*8+ch])
            $fatal(1,"GAP_MISMATCH w=%0d ch=%0d got=%0d ref=%0d",
              w,ch,$signed(dut.gap[ch]),$signed(gap_ref[w*8+ch]));
      end

      got_value=logits0;reference_value=ref_mem[w*4+0];if(got_value==reference_value) logit_matches=logit_matches+1;else if(w<32) $display("LOGIT MISMATCH w=%0d c=0 got=%0d ref=%0d",w,got_value,reference_value);
      got_value=logits1;reference_value=ref_mem[w*4+1];if(got_value==reference_value) logit_matches=logit_matches+1;else if(w<32) $display("LOGIT MISMATCH w=%0d c=1 got=%0d ref=%0d",w,got_value,reference_value);
      got_value=logits2;reference_value=ref_mem[w*4+2];if(got_value==reference_value) logit_matches=logit_matches+1;else if(w<32) $display("LOGIT MISMATCH w=%0d c=2 got=%0d ref=%0d",w,got_value,reference_value);
      got_value=logits3;reference_value=ref_mem[w*4+3];if(got_value==reference_value) logit_matches=logit_matches+1;else if(w<32) $display("LOGIT MISMATCH w=%0d c=3 got=%0d ref=%0d",w,got_value,reference_value);

      best_class=0;if(logits1>logits0) best_class=1;if(logits2>logits0 && logits2>logits1) best_class=2;if(logits3>logits0 && logits3>logits1 && logits3>logits2) best_class=3;
      got_pred=best_class;expected_pred=pred_mem[w];expected_label=label_mem[w];rtl_pred_mem[w]=got_pred;
      if(got_pred==expected_pred) pred_matches=pred_matches+1;else begin err_count=err_count+1;if(err_count<=20) $display("PRED MISMATCH w=%0d got=%0d ref=%0d label=%0d",w,got_pred,expected_pred,expected_label);end
      case(expected_label)
        0: begin class_total0=class_total0+1;if(got_pred==expected_label) class_correct0=class_correct0+1;end
        1: begin class_total1=class_total1+1;if(got_pred==expected_label) class_correct1=class_correct1+1;end
        2: begin class_total2=class_total2+1;if(got_pred==expected_label) class_correct2=class_correct2+1;end
        3: begin class_total3=class_total3+1;if(got_pred==expected_label) class_correct3=class_correct3+1;end
      endcase
      if ((w % 64) == 63 || run_windows <= 8) begin
        $display("Progress: %0d/%0d windows",w+1,run_windows);
        $fflush();
      end
      @(posedge clk);
    end

    // Explicit back-to-back normal -> outer without reset.
    @(negedge clk);start=1;@(negedge clk);start=0;
    for(s=0;s<W;s=s+1) begin
      while(!window_ready) @(negedge clk);
      window_sample=in_mem[s];window_valid=1;@(negedge clk);window_valid=0;
    end
    wait(done);@(posedge clk);
    if(logits0!==ref_mem[0]) begin $display("ERROR: back-to-back normal mismatch c0");$fatal(1);end
    if(logits1!==ref_mem[1]) begin $display("ERROR: back-to-back normal mismatch c1");$fatal(1);end
    if(logits2!==ref_mem[2]) begin $display("ERROR: back-to-back normal mismatch c2");$fatal(1);end
    if(logits3!==ref_mem[3]) begin $display("ERROR: back-to-back normal mismatch c3");$fatal(1);end

    @(negedge clk);start=1;@(negedge clk);start=0;
    for(s=0;s<W;s=s+1) begin
      while(!window_ready) @(negedge clk);
      window_sample=in_mem[384*W+s];window_valid=1;@(negedge clk);window_valid=0;
    end
    wait(done);@(posedge clk);
    if(logits0!==ref_mem[384*4+0]) begin $display("ERROR: back-to-back outer mismatch c0");$fatal(1);end
    if(logits1!==ref_mem[384*4+1]) begin $display("ERROR: back-to-back outer mismatch c1");$fatal(1);end
    if(logits2!==ref_mem[384*4+2]) begin $display("ERROR: back-to-back outer mismatch c2");$fatal(1);end
    if(logits3!==ref_mem[384*4+3]) begin $display("ERROR: back-to-back outer mismatch c3");$fatal(1);end

    // Explicit same-window repeat without reset.
    @(negedge clk);start=1;@(negedge clk);start=0;
    for(s=0;s<W;s=s+1) begin
      while(!window_ready) @(negedge clk);
      window_sample=in_mem[s];window_valid=1;@(negedge clk);window_valid=0;
    end
    wait(done);@(posedge clk);
    repeat_logit0=logits0;repeat_logit1=logits1;repeat_logit2=logits2;repeat_logit3=logits3;

    @(negedge clk);start=1;@(negedge clk);start=0;
    for(s=0;s<W;s=s+1) begin
      while(!window_ready) @(negedge clk);
      window_sample=in_mem[s];window_valid=1;@(negedge clk);window_valid=0;
    end
    wait(done);@(posedge clk);
    if(logits0!==repeat_logit0 || logits1!==repeat_logit1 || logits2!==repeat_logit2 || logits3!==repeat_logit3) begin
      $display("ERROR: same-window repeat mismatch");
      $fatal(1);
    end
    $display("BACK_TO_BACK_TEST_PASSED");
    $display("SAME_WINDOW_REPEAT_PASSED");

    // Cross-check the RTL's label-error indices against the Python reference.
    ref_error_count=0;rtl_error_count=0;common_error_count=0;
    rtl_only_error_count=0;ref_only_error_count=0;
    $write("REFERENCE_ERROR_INDICES=");
    for(w=0;w<run_windows;w=w+1) begin
      ref_bad=(pred_mem[w] != label_mem[w]);
      rtl_bad=(rtl_pred_mem[w] != label_mem[w]);
      if(ref_bad) begin
        ref_error_count=ref_error_count+1;
        $write("%0d,",w);
      end
      if(rtl_bad) rtl_error_count=rtl_error_count+1;
      if(ref_bad && rtl_bad) common_error_count=common_error_count+1;
      else if(rtl_bad) rtl_only_error_count=rtl_only_error_count+1;
      else if(ref_bad) ref_only_error_count=ref_only_error_count+1;
    end
    $display("");
    $write("RTL_ERROR_INDICES=");
    for(w=0;w<run_windows;w=w+1)
      if(rtl_pred_mem[w] != label_mem[w]) $write("%0d,",w);
    $display("");
    $display("ERROR_INDEX_COUNTS reference=%0d rtl=%0d common=%0d rtl_only=%0d reference_only=%0d",
      ref_error_count,rtl_error_count,common_error_count,rtl_only_error_count,ref_only_error_count);
    if (run_windows >= 32)
      $display("INTERMEDIATE_TENSOR_CHECKS_PASS windows=32 conv1=65536 pool=32768 conv2=32768 gap=256");
    if (run_windows == N &&
        (ref_error_count != 50 || rtl_error_count != 50 ||
         common_error_count != 50 || rtl_only_error_count != 0 ||
         ref_only_error_count != 0))
      $fatal(1,"ERROR_INDEX_CROSSCHECK_FAILED");
    if (overflow_seen !== 1'b0)
      $fatal(1,"SYSTOLIC_OVERFLOW_DETECTED during CNN inference");
    $display("SYSTOLIC_OVERFLOW_CHECK_PASS");

    $display("");$display("=== CNN E2E RESULT ===");$display("Windows: %0d",run_windows);
    $display("Exact logits: %0d/%0d",logit_matches,run_windows*4);
    $display("Prediction/reference: %0d/%0d",pred_matches,run_windows);
    $display("True-label accuracy: %0d/%0d",class_correct0+class_correct1+class_correct2+class_correct3,run_windows);
    $display("Class 0: %0d/%0d errors=%0d",class_correct0,class_total0,class_total0-class_correct0);$display("Class 1: %0d/%0d errors=%0d",class_correct1,class_total1,class_total1-class_correct1);
    $display("Class 2: %0d/%0d errors=%0d",class_correct2,class_total2,class_total2-class_correct2);$display("Class 3: %0d/%0d errors=%0d",class_correct3,class_total3,class_total3-class_correct3);
    $display("Reference expected accuracy: 462/512 = 90.234375%%");
    $display("TOTAL_DUT_CLOCK_CYCLES=%0d",cycle_count);
    $display("WINDOW_LATENCY_CYCLES min=%0d max=%0d avg=%0d",
      latency_min,latency_max,latency_sum/run_windows);
    if(pred_matches!=run_windows) begin $display("ERROR: RTL/reference prediction count is %0d, expected %0d",pred_matches,run_windows);$fatal(1);end
    if(logit_matches!=run_windows*4) begin $display("ERROR: Exact logits mismatch");$fatal(1);end
    $display("CNN_E2E_TEST_PASSED");$finish(0);
  end

  initial begin repeat(10000000) @(posedge clk);$display("ERROR: CNN simulation timeout");$fatal(1);end
endmodule
