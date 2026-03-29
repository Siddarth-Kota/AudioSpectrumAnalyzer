`timescale 1ns / 1ps

module Window (
    //Global signals
    input wire clk,
    input wire rst,

    input wire [23:0] audio_data,
    input wire data_valid,
    
    //Output to Buffer Block
    output reg signed [15:0] windowed_data,
    output reg window_valid
    );

endmodule