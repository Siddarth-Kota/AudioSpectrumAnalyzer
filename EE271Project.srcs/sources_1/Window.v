`timescale 1ns / 1ps

module Window #(
    parameter FFT_SIZE = 1024,
    parameter LOG2_FFT = 10
    )(
    input  wire clk,
    input  wire rst, // Active high reset
    
    // AXI-Stream Input (From Mic)
    input  wire signed [23:0] audio_data_in,
    input  wire s_valid,
    output wire s_ready,
    
    // AXI-Stream Output (To Buffer/FFT)
    output reg signed  [15:0] windowed_data_out,
    output reg m_valid,
    input  wire m_ready
    );

    reg [LOG2_FFT-1:0] sample_idx;
    reg signed [15:0] window_rom [0:FFT_SIZE-1];
    
    initial begin
        $readmemh("window_coeffs.mem", window_rom); 
    end

    reg signed [23:0] pipe_audio;
    reg signed [15:0] pipe_coeff;
    reg pipe_valid_1;
    reg pipe_valid_2;
    
    reg signed [39:0] result;

    assign s_ready = m_ready || !m_valid;

    always @(posedge clk or posedge rst) begin 
        if (rst) begin
            sample_idx <= 0;
            m_valid <= 0;
            pipe_valid_1 <= 0;
            pipe_valid_2 <= 0;
            pipe_coeff <= 0; 
            windowed_data_out <= 0;
        end else begin
            if (m_ready || !m_valid) begin
                
                if (s_valid && s_ready) begin
                    pipe_audio <= audio_data_in;
                    pipe_coeff <= window_rom[sample_idx]; 
                    sample_idx <= (sample_idx == FFT_SIZE - 1) ? 0 : sample_idx + 1;
                end
                
                pipe_valid_1 <= (s_valid && s_ready);
                if (pipe_valid_1) begin
                    result <= pipe_audio * pipe_coeff; 
                end

                pipe_valid_2 <= pipe_valid_1;
                if (pipe_valid_2) begin
                    windowed_data_out <= result[38:23]; //isolating significant bits and discarding the rest (keep 16 bits)
                end

                m_valid <= pipe_valid_2;
            end
        end
    end
endmodule