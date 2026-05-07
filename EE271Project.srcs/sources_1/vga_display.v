`include "vga_square.v"
`include "vga_graph_border.v"
`include "vga_FFT_in_stream.v"

module vga_display(sys_clk, reset, btn_r, valid, db, sw, Hsync, Vsync, vgaRed, vgaGreen, vgaBlue);
    input wire sys_clk;
    input wire reset;
    input wire btn_r;
    input wire valid;
    input wire [6:0] db;
    input wire [15:0] sw;
    output wire Hsync;
    output wire Vsync;
    output wire [3:0] vgaRed;
    output wire [3:0] vgaGreen;
    output wire [3:0] vgaBlue;

    // clk divider
    reg [9:0] divider_clk;
    wire pixel_clk;
    assign pixel_clk = divider_clk[1];  // 25MHz clk

    reg initial_reset;
    reg [24:0] initial_counter_reset;

    always@(posedge sys_clk)
    begin
        initial_reset <= 1;
        initial_counter_reset <= 1;
        if(initial_reset)
        begin
            initial_counter_reset <= initial_counter_reset + 1;
        end

        if(initial_counter_reset >= 250000)
        begin
            initial_reset <= 0;
            initial_counter_reset <= 250000;
        end
    end

    wire global_rst;
    assign global_rst = reset | initial_reset;
    always@(posedge sys_clk)
    begin
        if(global_rst)
        begin
            divider_clk <= 0;
        end
        if(initial_counter_reset > 25000)
        begin
            divider_clk <= divider_clk + 1;
        end
    end

    reg [11:0] h_count;
    reg [11:0] v_count;

    // // 1920 x 1080
    // localparam h_active_video = 1920,
    //            h_front_porch  = 88,
    //            h_sync_pulse   = 44,
    //            h_back_porch   = 148,
    //            v_active_video = 1080,
    //            v_front_porch  = 4,
    //            v_sync_pulse   = 5,
    //            v_back_porch   = 36;

    // 640 x 480
    localparam h_active_video = 640,
               h_front_porch  = 16,
               h_sync_pulse   = 96,
               h_back_porch   = 48,
               v_active_video = 480,
               v_front_porch  = 11,
               v_sync_pulse   = 2,
               v_back_porch   = 31;

    localparam state_active_video = 0,
               state_front_porch  = 1,
               state_sync_pulse   = 2,
               state_back_porch   = 3;

    // h_count and v_count logic
    always@(posedge pixel_clk)
    begin
        if(global_rst)
        begin
            h_count <= 0;
            v_count <= 0;
        end
        else if(h_count >= (h_active_video + h_front_porch + h_sync_pulse + h_back_porch))
        begin
            h_count <= 0;
            if(v_count >= (v_active_video + v_front_porch + v_sync_pulse + v_back_porch))
                v_count <= 0;
            else
                v_count <= v_count + 1;
        end
        else
            h_count <= h_count + 1;
    end
    
    // Hsync state logic
    reg [1:0] hsync_state;
    always@(*)
    begin
        if(global_rst)
            hsync_state = state_active_video;
        else if(h_count < h_active_video)
            hsync_state = state_active_video;
        else if(h_count < (h_active_video + h_front_porch))
            hsync_state = state_front_porch;
        else if(h_count < (h_active_video + h_front_porch + h_sync_pulse))
            hsync_state = state_sync_pulse;
        else if(h_count < (h_active_video + h_front_porch + h_sync_pulse + h_back_porch))
            hsync_state = state_back_porch;
        else
            hsync_state = state_active_video;
    end

    // Vsync state logic
    reg [1:0] vsync_state;
    always@(*)
    begin
        if(global_rst)
            vsync_state = state_active_video;
        else if(v_count < v_active_video)
            vsync_state = state_active_video;
        else if(v_count < (v_active_video + v_front_porch))
            vsync_state = state_front_porch;
        else if(v_count < (v_active_video + v_front_porch + v_sync_pulse))
            vsync_state = state_sync_pulse;
        else if(v_count < (v_active_video + v_front_porch + v_sync_pulse + v_back_porch))
            vsync_state = state_back_porch;
        else
            vsync_state = state_active_video;
    end

    wire square_flag;
    wire [3:0] square_red;
    wire [3:0] square_green;
    wire [3:0] square_blue;

    vga_square square (.pixel_clk(pixel_clk),
                       .reset(global_rst),
                       .h_count(h_count),
                       .v_count(v_count),
                       .h_active_video(h_active_video),
                       .v_active_video(v_active_video),
                       .display_red(square_red),
                       .display_green(square_green),
                       .display_blue(square_blue),
                       .display_flag(square_flag));

    wire axis_flag;
    wire [3:0] axis_red;
    wire [3:0] axis_green;
    wire [3:0] axis_blue;

    vga_graph_border axis  (.main_clk(sys_clk),
                            .pixel_clk(pixel_clk),
                            .reset(global_rst),
                            .h_count(h_count),
                            .v_count(v_count),
                            .display_red(axis_red),
                            .display_green(axis_green),
                            .display_blue(axis_blue),
                            .display_flag(axis_flag));
    
    // reg valid_temp;
    // reg [6:0] db_temp;
    // always@(posedge sys_clk)
    // begin
    //     if(global_rst)
    //     begin
    //         valid_temp <= 0;
    //         db_temp <= 0;
    //     end
    //     else if(valid_temp == 0)
    //     begin
    //         valid_temp <= 1;
    //         db_temp <= 110;
    //     end
    //     else
    //     begin
    //         valid_temp <= 1;
    //         if(db_temp >= 50)
    //             db_temp <= 0;
    //         else
    //             db_temp <= db_temp+1;
    //     end
    // end

    wire FFT_flag;
    wire [3:0] FFT_red;
    wire [3:0] FFT_green;
    wire [3:0] FFT_blue;

    vga_FFT_in_stream data_stream  (.main_clk(sys_clk),
                                    .pixel_clk(pixel_clk),
                                    .reset(global_rst),
                                    .valid(valid),
                                    .db(db),
                                    .h_count(h_count),
                                    .v_count(v_count),
                                    .sw(sw),
                                    .display_red(FFT_red),
                                    .display_green(FFT_green),
                                    .display_blue(FFT_blue),
                                    .display_flag(FFT_flag));




    // Hsync and Vsync output logic
    reg hsync_reg;
    reg vsync_reg;
    assign Hsync = hsync_reg;
    assign Vsync = vsync_reg;
    always@(*)
    begin
        case(hsync_state)
            state_active_video  :   hsync_reg = 1;
            state_front_porch   :   hsync_reg = 1;
            state_sync_pulse    :   hsync_reg = 0;
            state_back_porch    :   hsync_reg = 1;
            default             :   hsync_reg = 1;
        endcase

        case(vsync_state)
            state_active_video  :   vsync_reg = 1;
            state_front_porch   :   vsync_reg = 1;
            state_sync_pulse    :   vsync_reg = 0;
            state_back_porch    :   vsync_reg = 1;
            default             :   vsync_reg = 1;
        endcase
    end

    // color output logic
    reg [3:0] vgaRed_reg;
    reg [3:0] vgaGreen_reg;
    reg [3:0] vgaBlue_reg;
    assign vgaRed = vgaRed_reg;
    assign vgaGreen = vgaGreen_reg;
    assign vgaBlue = vgaBlue_reg;
    always@(*)
    begin
        if((hsync_state == state_active_video) && (vsync_state == state_active_video))
        begin
            if(FFT_flag)
            begin
                vgaRed_reg   = FFT_red;
                vgaGreen_reg = FFT_green;
                vgaBlue_reg  = FFT_blue;
            end
            else if(axis_flag)
            begin
                vgaRed_reg   = axis_red;
                vgaGreen_reg = axis_green;
                vgaBlue_reg  = axis_blue;
            end
            else if(square_flag)
            begin
                vgaRed_reg   = square_red;
                vgaGreen_reg = square_green;
                vgaBlue_reg  = square_blue;
            end
            else    // background
            begin
                vgaRed_reg   = 0;
                vgaGreen_reg = 0;
                vgaBlue_reg  = 0;
            end
        end 
        else
        begin
            vgaRed_reg   = 0;
            vgaGreen_reg = 0;
            vgaBlue_reg  = 0;
        end
    end

endmodule


