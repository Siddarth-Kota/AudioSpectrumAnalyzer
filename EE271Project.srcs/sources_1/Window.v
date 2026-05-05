`timescale 1ns / 1ps

module Window #(
    parameter FFT_SIZE = 1024,
    parameter LOG2_FFT = 10
    )(
    input  wire clk,
    input  wire rst, // Active high reset -Karlo
    
    // From I2S Receiver
    input  wire signed [23:0] audio_data_in,
    input  wire data_valid_in,
    
    // To Buffer/FFT
    output reg signed  [15:0] windowed_data_out,
    output reg data_valid_out
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

    always @(posedge clk, posedge rst) begin      // made asynchronous so reset will actually trigger these before clock begins
        if (rst) begin
            sample_idx <= 0;
            data_valid_out <= 0;
            pipe_valid_1 <= 0;
            pipe_valid_2 <= 0;
            pipe_coeff <= 0;            // added reset state -Karlo
        end else begin
            pipe_valid_1 <= data_valid_in;
            if (data_valid_in) begin
                pipe_audio <= audio_data_in;
                pipe_coeff <= window_rom[sample_idx]; //window coefficient for current sample index
                
                sample_idx <= (sample_idx == FFT_SIZE - 1) ? 0 : sample_idx + 1; //Wrap to 0 after maxing for FFT_SIZE
            end

            pipe_valid_2 <= pipe_valid_1;
            if (pipe_valid_1) begin
                result <= pipe_audio * pipe_coeff; 
            end

            data_valid_out <= pipe_valid_2;
            if (pipe_valid_2) begin
                windowed_data_out <= result[38:23]; //isolating significant bits for output (16 out of 40 bits)
            end
        end
    end
endmodule