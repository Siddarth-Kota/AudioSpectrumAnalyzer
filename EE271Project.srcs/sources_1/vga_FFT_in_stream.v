module vga_FFT_in_stream(main_clk, pixel_clk, reset, valid, db, h_count, v_count, display_red, display_green, display_blue, display_flag);
    input wire main_clk;
    input wire pixel_clk;
    input wire reset;
    input wire valid;
    input wire [6:0] db;
    input wire [11:0] h_count;
    input wire [11:0] v_count;

    output wire [3:0] display_red;
    output wire [3:0] display_green;
    output wire [3:0] display_blue;
    output wire display_flag;

    localparam n_pt_fft = 1024,
               usable_fft = n_pt_fft/2;
               
    reg [6:0] bin[usable_fft:0];  // 6 bits for each row x 513 rows
    reg [9:0] index;

    // we want to display data in batches 
    // data comes in batches of 1024 since it is a 1024-pt FFT
    // only the first half of data points are valid since that will represent bins whose frequency are half of the sampling (nyquists)
    // when we are intaking data, we wait until all the 513 points are taken in to start displaying
    // when we are displaying, we wait until we are done displaying to start taking in new data

    localparam s0_waiting = 0,
               s1_intaking = 1,
               s2_displaying = 2,
               s3_displaying = 3,
               s4_displaying = 4;
    
    reg [2:0] state;
    reg [2:0] next_state;

    always@(posedge main_clk)
    begin
        if(reset)
            state <= s0_waiting;
        else
            state <= next_state;
    end

    always@(*)
    begin
        if(state == s0_waiting)
        begin
            if(valid && (index == (n_pt_fft-1)))
            begin
                next_state = s1_intaking;
            end
            else
                next_state = s0_waiting;
        end
        
        else if(state == s1_intaking)
        begin
            if(index == usable_fft)
                next_state = s2_displaying;
            else
                next_state = s1_intaking;
        end
        
        else if(state == s2_displaying)
        begin
            if((h_count == 0) && (v_count == 0))
                next_state = s3_displaying;
            else
                next_state = s2_displaying;
        end

        else if(state == s3_displaying)
        begin
            if((h_count != 0) && (v_count != 0))
                next_state = s4_displaying;
            else
                next_state = s3_displaying;
        end

        else if(state == s4_displaying)
        begin
            if((h_count == 0) && (v_count == 0))
                next_state = s0_waiting;
            else
                next_state = s4_displaying;
        end
    end

    // track bin intake progress
    // assumption is that once valid goes high it stays high
    integer i;
    always@(posedge main_clk)
    begin
        if(reset)
        begin
            index <= 0;
            for(i = 0; i <= usable_fft; i = i + 1)
            begin
                bin[i] <= 0;
            end
        end
        else 
        begin
            if(valid)
            begin
                index <= index + 1;
                if(state == s1_intaking)
                begin
                    bin[index] <= db;
                end
            end
            else
                index <= 0;
        end
    end

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

    // check to see if h_count and v_count are within graph bounds
    wire graph_check;
    assign graph_check = ((state == s2_displaying) || (state == s3_displaying)|| (state == s4_displaying)) &&
                         ((h_count >= (x_axis_h_origin + y_axis_width + 1)) && (h_count < (x_axis_h_origin + y_axis_width + usable_fft + 1))) &&
                         (v_count >= y_axis_v_origin && (v_count < (y_axis_v_origin + y_axis_length))) ? 1 : 0;
    
    // check to see if there is a data point at the current h_count and v_count number
    // only if we are within the graphical bounds
    reg data_check;
    integer current_bin;
    reg [3:0] color_red;
    reg [3:0] color_green;
    reg [3:0] color_blue;
    localparam max_v_count_graph = (y_axis_v_origin + y_axis_length - 1),
               min_v_count_graph = y_axis_v_origin;
    always@(*)
    begin
        data_check = 0;
        color_red = 4'b1111;
        color_green = 0;
        color_blue = 0;
        if(graph_check)
        begin
            current_bin = h_count - (x_axis_h_origin + y_axis_width + 1);
            if(v_count >= (410 - ((bin[current_bin] << 1) + bin[current_bin])))
            begin
                data_check = 1;
                // calculate color for data point
                //color_red = (15*(max_v_count_graph - v_count))/(max_v_count_graph - min_v_count_graph); // top color
                color_green = (15*(v_count - min_v_count_graph))/(max_v_count_graph - min_v_count_graph); // bot color
            end
        end
    end

    assign display_flag = data_check & graph_check;
    assign display_red = color_red;
    assign display_green = color_green;
    assign display_blue = color_blue;
endmodule