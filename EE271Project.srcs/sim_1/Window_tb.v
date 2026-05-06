`timescale 1ns / 1ps

module tb_Window;
    reg clk;
    reg rst_n;
    reg signed [23:0] audio_data_in;
    reg data_valid_in;
    
    wire signed [15:0] windowed_data_out;
    wire data_valid_out;

    Window dut (
        .clk(clk),
        .rst_n(rst_n),
        .audio_data_in(audio_data_in),
        .data_valid_in(data_valid_in),

        .windowed_data_out(windowed_data_out),
        .data_valid_out(data_valid_out)
    );

    always #5 clk = ~clk;
    integer i;

    initial begin
        clk = 0;
        rst_n = 0;
        audio_data_in = 24'd0;
        data_valid_in = 0;

        #100;
        rst_n = 1;

        repeat(5) @(posedge clk);

        $display("Starting Window Module Testbench");
        for (i = 0; i < 1024; i = i + 1) begin
            audio_data_in <= 24'd1000000; 
            data_valid_in <= 1'b1;
            
            @(posedge clk);
            data_valid_in <= 1'b0;
            repeat(10) @(posedge clk);
        end

        repeat(10) @(posedge clk);

        $display("Test finished.");
        $finish;
    end

    always @(posedge clk) begin
        if (data_valid_out) begin
            $display("Sample Output: %d", windowed_data_out);
        end
    end
endmodule