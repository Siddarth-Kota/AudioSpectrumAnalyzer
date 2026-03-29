module ComplexToPower (
    input wire [31:0] in,
    output reg[32:0] power,
    input wire clk
);
    wire [15:0] re;
    wire [15:0] im;

    reg [31:0] re_sq, im_sq;

    assign re = in[31:16];
    assign im = in[15:0];

    always @(posedge clk) begin
        re_sq <= re * re;
        im_sq <= im * im;
    end

    always @(posedge clk) begin
        power <= re_sq + im_sq;
    end


endmodule