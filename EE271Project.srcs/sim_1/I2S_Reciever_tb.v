`timescale 1ns / 1ps

module I2S_Receiver_tb;
    reg  clk;
    reg  rst_n;
    reg  sd;
    
    wire bclk;
    wire ws;
    wire [23:0] audio_data;
    wire data_valid;

    I2S_Receiver dut (
        .clk(clk),
        .rst_n(rst_n),
        .sd(sd),
        .bclk(bclk),
        .ws(ws),
        .audio_data(audio_data),
        .data_valid(data_valid)
    );

    always #5 clk = ~clk;

    reg [23:0] test_pattern = 24'hA5A5A5; 
    integer i;

    initial begin
        clk   = 0;
        rst_n = 0;
        sd    = 0;

        #100;
        rst_n = 1;

        $display("Starting I2S Receiver Testbench");

        @(negedge bclk);

        for (i = 23; i >= 0; i = i - 1) begin
            sd = test_pattern[i];
            @(negedge bclk);
        end

        sd = 0;
        for (i = 0; i < 8; i = i + 1) begin
            @(negedge bclk);
        end
        #1000;
        $display("Simulation timeout. Data valid was never triggered.");
        $finish;
    end
    always @(posedge clk) begin
        if (data_valid) begin
            if (audio_data == test_pattern) begin
                $display("SUCCESS: audio_data exactly matched test_pattern (%h)!", audio_data);
            end else begin
                $display("ERROR: Expected %h but got %h", test_pattern, audio_data);
            end
            $finish;
        end
    end
endmodule