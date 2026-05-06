module ComplexToPower (
    input wire [63:0] fft_tdata, //note this is assuming vivado fft block in unscaled mode, lmk if we use scaled 
    input wire fft_tvalid,
    output reg[26:0] mag, //also changes if we use scaled, this is for unscaled
    output reg mag_valid,
    input wire clk,
    input wire reset
);
    wire [26:0] re = fft_tdata[26:0];
    wire [26:0] im = fft_tdata[58:32];

    wire [26:0] abs_re = re[26] ? -re : re; //turns out fft output is in 2's complement, so we need to take the absolute value
    wire [26:0] abs_im = im[26] ? -im : im;


     always @(posedge clk or posedge reset) begin
        if (reset) begin
            mag       <= 0;
            mag_valid <= 0;
        end else begin
            mag       <= (abs_re > abs_im) ? abs_re : abs_im;
            mag_valid <= fft_tvalid;
        end
    end



endmodule