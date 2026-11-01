`timescale 1ns/1ps

module tb_motor_features;
    logic clk = 0;
    logic rst_n = 0;
    logic start = 0;
    logic signed [15:0] sample_in;
    logic sample_valid = 0;
    logic sample_ready, busy, done;
    logic [31:0] mean_square;
    logic [15:0] rms;
    logic signed [15:0] peak_to_peak;

    logic signed [15:0] samples [0:255];
    integer i;

    always #10 clk = ~clk;

    motor_vibration_feature_engine dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .sample_in(sample_in),
        .sample_valid(sample_valid),
        .sample_ready(sample_ready),
        .busy(busy),
        .done(done),
        .mean_square(mean_square),
        .rms(rms),
        .peak_to_peak(peak_to_peak)
    );

    initial begin
        $readmemh("quartus/de10_motor_vibration/motor_vibration.hex", samples);

        repeat (3) @(posedge clk);
        rst_n = 1;
        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        for (i = 0; i < 256; i = i + 1) begin
            while (!sample_ready) @(negedge clk);
            sample_in = samples[i];
            sample_valid = 1;
            @(negedge clk);
            sample_valid = 0;
        end

        wait(done);
        #1;
        $display("RTL mean-square: %0d", mean_square);
        $display("RTL RMS:         %0d", rms);
        $display("RTL peak-to-peak:%0d", peak_to_peak);

        if (rms != 922 || peak_to_peak != 5588)
            $fatal(1, "Feature mismatch!");

        $display("PASS: RTL features match expected reference.");
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "TIMEOUT");
    end
endmodule
