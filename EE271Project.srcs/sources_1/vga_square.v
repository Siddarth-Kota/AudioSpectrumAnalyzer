module vga_square(pixel_clk, reset, h_count, v_count, h_active_video, v_active_video, display_red, display_green, display_blue, display_flag);
    input wire pixel_clk;
    input wire reset;
    input wire [11:0] h_count;
    input wire [11:0] v_count;
    input wire [11:0] h_active_video;
    input wire [11:0] v_active_video;

    output wire [3:0] display_red;
    output wire [3:0] display_green;
    output wire [3:0] display_blue;
    output wire display_flag;

    localparam object_width = 25,       // square width is 50 so half width is 25
               object_movement = 20;    // every second, it moves 20

    // square will be blue
    assign display_red = 4'b0000;
    assign display_green = 4'b0000;
    assign display_blue = 4'b1111;

    wire object_h_bound;
    wire object_v_bound;
    reg [9:0] object_h_origin;
    reg [9:0] object_v_origin;

    // bounds are determined by +/- object width from origin
    assign object_h_bound = ((h_count > object_h_origin - object_width) & (h_count < object_h_origin + object_width)) ? 1'b1 : 1'b0;
    assign object_v_bound = ((v_count > object_v_origin - object_width) & (v_count < object_v_origin + object_width)) ? 1'b1 : 1'b0;

    // display flag is high when the h_count AND v_count are between bounds of the square
    assign display_flag = (object_h_bound & object_v_bound) ? 1'b1 : 1'b0;

    reg [24:0] sec1_display_counter; // 1 second counter assumming 25MHz clock

    // move the square origin once every second
    always@(posedge pixel_clk)
    begin
        if(reset)
        begin
            sec1_display_counter <= 0;
            object_h_origin <= 0;
            object_v_origin <= v_active_video/2;
        end
        else
        begin
            sec1_display_counter <= sec1_display_counter + 1;

            if(sec1_display_counter >= 25000000)
            begin
                sec1_display_counter <= 0;
                object_h_origin <= object_h_origin + object_movement;
                if(object_h_origin + object_width + object_movement > h_active_video)
                begin
                    object_h_origin <= 0;
                end
            end
        end
    end
endmodule