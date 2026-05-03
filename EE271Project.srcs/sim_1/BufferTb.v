`timescale 1ns / 1ps

module buffer_tb;

    reg clk;
    reg rst_n;

    reg signed [15:0] windowed_data;
    reg window_valid;

    wire signed [15:0] data_out;
    wire data_valid;

    // Instantiate buffer
    buffer_final uut (
        .clk(clk),
        .rst_n(rst_n),
        .windowed_data(windowed_data),
        .window_valid(window_valid),
        .data_out(data_out),
        .data_valid(data_valid)
    );

    // Clock generation (100MHz)
    always #5 clk = ~clk;

    integer i;

    initial begin
        // Init
        clk = 0;
        rst_n = 0;
        windowed_data = 0;
        window_valid = 0;

        // Reset
        #20;
        rst_n = 1;

        // =========================
        // WRITE 1024 SAMPLES
        // =========================
        for (i = 0; i < 1024; i = i + 1) begin
            @(posedge clk);
            window_valid = 1;
            windowed_data = i;   // simple ramp
        end

        // Stop writing
        @(posedge clk);
        window_valid = 0;

        // =========================
        // WAIT FOR READ OUTPUT
        // =========================
        #20000;

        $finish;
    end

    // Monitor output
    always @(posedge clk) begin
        if (data_valid) begin
            $display("Time=%0t | OUTPUT = %d", $time, data_out);
        end
    end

endmodule