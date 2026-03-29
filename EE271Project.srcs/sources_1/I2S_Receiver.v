`timescale 1ns / 1ps

module I2S_Receiver(
    //Global signals
    input wire clk,
    input wire rst,

    // I2S signals from Mic
    input wire sck,
    input wire ws,
    input wire sd,

    //Output to Window Block
    output reg [23:0] audio_data,
    output reg data_valid
    );

endmodule