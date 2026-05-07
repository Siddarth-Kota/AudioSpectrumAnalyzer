`timescale 1ns / 1ps

module vga_tb;
    reg clk;
    reg reset;
    reg btn_r;
    wire Hsync;
    wire Vsync;
    wire valid;
    wire db;
    wire sw;
    wire [3:0] vgaRed;
    wire [3:0] vgaGreen;
    wire [3:0] vgaBlue;

    vga_display test(.sys_clk(clk),
                     .reset(reset),
                     .btn_r(btn_r),
                     .valid(valid),
                     .db(db),
                     .sw(sw),
                     .Hsync(Hsync),
                     .Vsync(Vsync),
                     .vgaRed(vgaRed),
                     .vgaGreen(vgaGreen),
                     .vgaBlue(vgaBlue));
    
    initial 
    begin
        clk = 0;
        reset = 1;
        #30
        reset = 0;
        #28000000
        $finish;
    end

    always #3 clk = ~clk;




endmodule