`timescale 1ns / 1ps

module tb_Window;
    reg clk;
    reg rst;
    
    // AXI-Stream Inputs to DUT
    reg signed [23:0] audio_data_in;
    reg s_valid;
    wire s_ready;
    
    // AXI-Stream Outputs from DUT
    wire signed [15:0] windowed_data_out;
    wire m_valid;
    reg m_ready;

    Window dut (
        .clk(clk),
        .rst(rst),
        .audio_data_in(audio_data_in),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .windowed_data_out(windowed_data_out),
        .m_valid(m_valid),
        .m_ready(m_ready)
    );

    always #5 clk = ~clk;
    integer i;

    //data production
    initial begin
        clk = 0;
        rst = 1;
        audio_data_in = 24'd0;
        s_valid = 0;

        #100;
        rst = 0;

        repeat(5) @(posedge clk);

        $display("Starting Window Module Testbench (AXI-Stream)");
        
        for (i = 0; i < 1024; i = i + 1) begin
            audio_data_in = 24'd1000000; 
            s_valid = 1'b1;

            while (!(s_valid && s_ready)) begin
                @(posedge clk);
            end
            
            @(posedge clk);
            
            s_valid = 1'b0;
            repeat(10) @(posedge clk);
        end

        repeat(20) @(posedge clk);

        $display("Test finished.");
        $finish;
    end

    //downstream stall simulation
    integer received_count = 0;
    
    initial begin
        m_ready = 1;
        
        wait(received_count == 512);
        
        $display("downstream stall start");
        m_ready = 0;
        
        repeat(1000) @(posedge clk);
        
        $display("downstream stall end");
        m_ready = 1;
    end

    always @(posedge clk) begin
        if (m_valid && m_ready) begin
            $display("Sample Output: %d", windowed_data_out);
            received_count = received_count + 1;
        end
    end

endmodule