`timescale 1ns / 1ps

module fft8_tb;

    reg clk;
    reg rst_n;

    reg signed [15:0] sample_in;
    reg sample_valid;

    wire [31:0] fft_out;
    wire valid_out;

    // Instantiate FFT
    fft8 uut (
        .clk(clk),
        .rst_n(rst_n),
        .sample_in(sample_in),
        .sample_valid(sample_valid),
        .fft_out(fft_out),
        .valid_out(valid_out)
    );

    // Clock
    always #5 clk = ~clk;

    integer i;

    // Test vector
    reg signed [15:0] test_data [0:7];

    initial begin
        clk = 0;
        rst_n = 0;
        sample_in = 0;
        sample_valid = 0;

        // Initialize impulse input
        test_data[0] = 16'd1000;
        test_data[1] = 0;
        test_data[2] = 0;
        test_data[3] = 0;
        test_data[4] = 0;
        test_data[5] = 0;
        test_data[6] = 0;
        test_data[7] = 0;

        // Reset
        #20;
        rst_n = 1;

        // =========================
        // SEND 8 SAMPLES
        // =========================
        for (i = 0; i < 8; i = i + 1) begin
            @(posedge clk);
            sample_valid = 1;
            sample_in = test_data[i];
        end

        // Stop input
        @(posedge clk);
        sample_valid = 0;

        // Wait for output
        #200;

        $finish;
    end

    // Monitor FFT output
    always @(posedge clk) begin
        if (valid_out) begin
            $display("Time=%0t | REAL=%d IMAG=%d",
                $time,
                fft_out[31:16],
                fft_out[15:0]
            );
        end
    end

endmodule