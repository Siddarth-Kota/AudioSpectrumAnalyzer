module vga_graph_border(main_clk, pixel_clk, reset, h_count, v_count, display_red, display_green, display_blue, display_flag);
    input wire main_clk;
    input wire pixel_clk;
    input wire reset;
    input wire [11:0] h_count;
    input wire [11:0] v_count;

    output wire [3:0] display_red;
    output wire [3:0] display_green;
    output wire [3:0] display_blue;
    output wire display_flag;

    // graph axis thickness 5 pixels
    localparam y_axis_width = 5,
               y_axis_length = 360,
               x_axis_width = 523,
               x_axis_length = 5;

    // axis origin is fixed since the graph will be fixed and not moving
    localparam y_axis_h_origin = 50,
               y_axis_v_origin = 50,
               x_axis_h_origin = 50,
               x_axis_v_origin = y_axis_v_origin + y_axis_length;
    
    // graph axis will be white
    assign display_red = 4'b1111;
    assign display_green = 4'b1111;
    assign display_blue = 4'b1111;

    wire y_axis_h_bound;
    wire y_axis_v_bound;    
    wire x_axis_h_bound;
    wire x_axis_v_bound;

    // bounds are determined by +/- object width from origin
    assign y_axis_h_bound = ((h_count >= y_axis_h_origin) && (h_count < (y_axis_h_origin + y_axis_width))) ? 1'b1 : 1'b0;
    assign y_axis_v_bound = ((v_count >= y_axis_v_origin) && (v_count < (y_axis_v_origin + y_axis_length))) ? 1'b1 : 1'b0;

    assign x_axis_h_bound = ((h_count >= x_axis_h_origin) && (h_count < (x_axis_h_origin + x_axis_width))) ? 1'b1 : 1'b0;
    assign x_axis_v_bound = ((v_count >= x_axis_v_origin) && (v_count < (x_axis_v_origin + x_axis_length))) ? 1'b1 : 1'b0;




    localparam grid_lines_spacing = 32;
            //    temp1 = (y_axis_v_origin + y_axis_length) / grid_lines_spacing,
            //    temp2 = (y_axis_v_origin + y_axis_length) - (temp1 * grid_lines_spacing);
    wire vertical_grid_lines_bound;
    assign vertical_grid_lines_bound = ((v_count >= y_axis_v_origin) && (v_count < y_axis_v_origin + y_axis_length)) && 
                                       ((h_count >= (x_axis_h_origin + y_axis_width)) && (h_count < (x_axis_h_origin + x_axis_width)))  &&
                                       (((h_count - (y_axis_h_origin + y_axis_width)) % grid_lines_spacing == 0)) ? 1'b1 : 1'b0;
    
    wire horizontal_grid_lines_bound;
    assign horizontal_grid_lines_bound = ((v_count > y_axis_v_origin) && (v_count < y_axis_v_origin + y_axis_length)) && 
                                         ((h_count >= (x_axis_h_origin + y_axis_width)) && (h_count < (x_axis_h_origin + x_axis_width)))  &&
                                         (((v_count - (y_axis_v_origin + y_axis_length)) % grid_lines_spacing == 0)) ? 1'b1 : 1'b0;

    // display flag is high when the h_count AND v_count are between bounds of the axis
    assign display_flag = (y_axis_h_bound && y_axis_v_bound) || (x_axis_h_bound && x_axis_v_bound) || vertical_grid_lines_bound || horizontal_grid_lines_bound;
endmodule