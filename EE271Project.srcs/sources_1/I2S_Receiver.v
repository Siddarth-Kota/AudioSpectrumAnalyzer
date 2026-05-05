`timescale 1ns / 1ps

module I2S_Receiver (
    //Global signals
    input wire clk,
    input wire rst, //Active low reset

    // I2S signals
    input wire sd,

    output reg bclk,
    output reg ws,

    //Output to Window Block
    output reg signed [23:0] audio_data,
    output reg data_valid
    );

    reg [4:0] clk_div; //for Bit Clock
    reg [5:0] bit_count;
    reg [23:0] shift_reg;

    always @(posedge clk) begin
        if(rst) begin
            clk_div <= 5'b0;
            bclk <= 1'b0;
            ws <= 1'b0;
            bit_count <= 6'b0;
            shift_reg <= 24'b0;
            audio_data <= 24'b0;
            data_valid <= 1'b0;
        end 
        else begin
            data_valid <= 1'b0;
            clk_div <= clk_div + 1;
            if(clk_div == 5'd15) begin
                bclk <= 1'b1;
                if(bit_count >= 6'd1 && bit_count <= 6'd24) begin
                    shift_reg <= {shift_reg[22:0], sd}; //Adds new bits to the right of existing ones
                end
            end
            else if(clk_div == 5'd31) begin
                bclk <= 1'b0;
                bit_count <= bit_count + 1;
                if(bit_count == 6'd31) begin
                    ws <= 1'b1; //Right Channel
                    audio_data <= shift_reg;
                    data_valid <= 1'b1;
                end
                else if(bit_count == 6'd63) begin
                    ws <= 1'b0; //Left Channel
                end
            end
        end
    end
endmodule