`timescale 1ns/1ps

module de10_motor_vibration_top (
    input  logic CLOCK_50,
    input  logic [0:0] KEY,
    input  logic [0:0] SW,
    output logic [9:0] LEDR
);

    logic [1:0] reset_sync;
    logic rst_n;
    logic sw_meta, sw_sync, sw_d;
    logic start;
    logic [7:0] index;
    logic [25:0] heartbeat;

    logic signed [15:0] sample_value;
    logic sample_valid, sample_ready;
    logic busy, done, done_latched;
    logic [31:0] mean_square;
    logic [15:0] rms;
    logic signed [15:0] peak_to_peak;

    motor_vibration_rom u_sample_rom (
        .addr(index),
        .data(sample_value)
    );
    assign sample_valid = busy && sample_ready;

    always_ff @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0])
            reset_sync <= 2'b00;
        else
            reset_sync <= {reset_sync[0], 1'b1};
    end

    assign rst_n = reset_sync[1];

    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            sw_meta <= 0;
            sw_sync <= 0;
            sw_d <= 0;
            start <= 0;
            index <= 0;
            heartbeat <= 0;
            done_latched <= 0;
        end else begin
            sw_meta <= SW[0];
            sw_sync <= sw_meta;
            sw_d <= sw_sync;
            start <= sw_sync && !sw_d && !busy;
            heartbeat <= heartbeat + 1'b1;

            if (start) begin
                index <= 0;
                done_latched <= 0;
            end else if (sample_valid) begin
                index <= index + 1'b1;
            end

            if (done)
                done_latched <= 1'b1;
        end
    end

    motor_vibration_feature_engine #(
        .WINDOW_SIZE(256),
        .INDEX_WIDTH(8)
    ) u_features (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .start(start),
        .sample_in(sample_value),
        .sample_valid(sample_valid),
        .sample_ready(sample_ready),
        .busy(busy),
        .done(done),
        .mean_square(mean_square),
        .rms(rms),
        .peak_to_peak(peak_to_peak)
    );

    assign LEDR[0] = heartbeat[25];
    assign LEDR[1] = busy;
    assign LEDR[2] = done_latched;
    assign LEDR[3] = (rms > 16'd1000);
    assign LEDR[4] = (peak_to_peak > 16'd3000);
    assign LEDR[9:5] = rms[4:0];

endmodule
