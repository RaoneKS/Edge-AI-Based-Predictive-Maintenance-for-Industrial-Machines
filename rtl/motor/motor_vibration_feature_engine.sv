`timescale 1ns/1ps

module motor_vibration_feature_engine #(
    parameter integer WINDOW_SIZE = 256,
    parameter integer INDEX_WIDTH = 8
) (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic signed [15:0] sample_in,
    input  logic sample_valid,
    output logic sample_ready,
    output logic busy,
    output logic done,
    output logic [31:0] mean_square,
    output logic [15:0] rms,
    output logic signed [15:0] peak_to_peak
);

    logic [INDEX_WIDTH-1:0] count;
    logic signed [15:0] minimum_sample, maximum_sample;
    logic [39:0] sum_squares;
    logic [39:0] next_sum;
    logic [31:0] square_value;

    logic [15:0] root;
    logic [4:0] sqrt_bit;
    logic [16:0] candidate;
    logic [33:0] candidate_square;
    logic calculating_sqrt;

    assign sample_ready = busy && !calculating_sqrt;

    always_comb begin
        square_value = sample_in * sample_in;
        next_sum = sum_squares + square_value;
        candidate = {1'b0, root} | (17'd1 << sqrt_bit);
        candidate_square = candidate * candidate;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 0;
            minimum_sample <= 16'sh7fff;
            maximum_sample <= -16'sh8000;
            sum_squares <= 0;
            mean_square <= 0;
            rms <= 0;
            peak_to_peak <= 0;
            root <= 0;
            sqrt_bit <= 0;
            calculating_sqrt <= 0;
            busy <= 0;
            done <= 0;
        end else begin
            done <= 0;

            if (start && !busy) begin
                count <= 0;
                minimum_sample <= 16'sh7fff;
                maximum_sample <= -16'sh8000;
                sum_squares <= 0;
                root <= 0;
                busy <= 1;
                calculating_sqrt <= 0;
            end

            if (busy && sample_valid && !calculating_sqrt) begin
                sum_squares <= sum_squares + square_value;

                if (sample_in < minimum_sample)
                    minimum_sample <= sample_in;

                if (sample_in > maximum_sample)
                    maximum_sample <= sample_in;

                if (count == WINDOW_SIZE-1) begin
                    mean_square <= next_sum >> 8;
                    peak_to_peak <=
                        (sample_in > maximum_sample ? sample_in : maximum_sample)
                        - (sample_in < minimum_sample ? sample_in : minimum_sample);

                    root <= 0;
                    sqrt_bit <= 15;
                    calculating_sqrt <= 1;
                end else begin
                    count <= count + 1'b1;
                end
            end

            if (busy && calculating_sqrt) begin
                if (candidate_square <= mean_square) begin
                    root <= candidate[15:0];
                end

                if (sqrt_bit == 0) begin
                    rms <= (candidate_square <= mean_square)
                         ? candidate[15:0] +
                           ((mean_square > candidate_square + candidate) ? 16'd1 : 16'd0)
                         : root +
                           ((mean_square > (root * root + root)) ? 16'd1 : 16'd0);
                    calculating_sqrt <= 0;
                    busy <= 0;
                    done <= 1;
                end else begin
                    sqrt_bit <= sqrt_bit - 1'b1;
                end
            end
        end
    end
endmodule
