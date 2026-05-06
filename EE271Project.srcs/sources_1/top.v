module top(
    input wire CLK,
    input wire RESET,

    output wire M_CLK,
    input wire M_DATA,      // input from ADMP
    output wire M_LRSEL,

    output wire [3:0] vgaRed,
    output wire [3:0] vgaGreen,
    output wire [3:0] vgaBlue,
    output wire Hsync,
    output wire Vsync
);

    // Clock Buffer
    reg clk_div;
    wire fclk;
    always @(posedge CLK, posedge RESET) begin
        if(RESET) begin 
            clk_div <= 0;
        end
        else begin 
            clk_div<=~clk_div;
        end
    end
    BUFG BUFG_CLK ( // 50 MHz CLK
        .O(fclk),
        .I(clk_div)
    );
    
    wire clk_mic_raw;
    wire clk_vga;
    reg clk_mic_actual;
    clk_wiz_0 clk0(
        .clk_mic(clk_mic_raw),  // 6 MHz CLK 
        .clk_vga(clk_vga),      // 100 MHz CLK
        .reset(RESET),
        .locked(),
        .clk_in1(fclk)
    );
    
    always @(posedge clk_mic_raw, posedge RESET) begin 
        if(RESET) begin 
            clk_mic_actual <= 0;
        end
        else begin 
            clk_mic_actual <= ~clk_mic_actual;   // 3 MHz CLK
        end
    end

    // generate CLK and SEL signals to receive PDM data
    mic m(
        .clk(clk_mic_actual),
        .reset(RESET),
        .m_clk(M_CLK),                          // 3 MHz CLK
        .m_lrsel(M_LRSEL)
    );

    // cic filter to convert from PDM to PCM
    wire [23:0] cic_dataout;
    wire cic_mvalid, fir_sready;
    cic c(
        .data_out(cic_dataout),
        .m_valid(cic_mvalid),
        .m_ready(fir_sready),
        .data_in(M_DATA),
        .clk(M_CLK),
        .reset(RESET)
    );

    wire [23:0] fir_dataout;
    wire        fir_mvalid, win_sready;
    fir f(
        .data_out(fir_dataout),
        .data_in(cic_dataout),
        .s_valid(cic_mvalid),
        .s_ready(fir_sready),
        .m_valid(fir_mvalid),
        .m_ready(win_sready),
        .clk(M_CLK),
        .reset(RESET)
    );
    
    wire [15:0] win_data_out;
    wire        win_mvalid, fifo1_sready;
    Window win(
        .clk(M_CLK),
        .rst(RESET),
        .audio_data_in(fir_dataout),
        .s_valid(fir_mvalid),
        .s_ready(win_sready),
        .m_valid(win_mvalid),
        .m_ready(fifo1_sready),
        .windowed_data_out(win_data_out)
    );
    reg [9:0] win_last_count;    
    // AXIS TLAST calculation
    always @(posedge M_CLK, posedge RESET) begin 
        if(RESET) begin 
            win_last_count <= 0;
        end
        else if (win_mvalid && fifo1_sready) begin 
            if(win_last_count == 10'd1023) win_last_count <= 0;
            else win_last_count <= win_last_count + 1;
        end
    end
    wire win_last;
    assign win_last = win_last_count == 10'd1023;
    wire        fifo1_mvalid;
    wire [15:0] fifo1_data_out;
    wire        fifo1_mlast;
    wire        fft_sready;

    axis_data_fifo_0 fifo1(
        .s_axis_aresetn(~RESET),
        .s_axis_aclk(M_CLK),            // 3 MHz CLK
        .s_axis_tvalid(win_mvalid),
        .s_axis_tready(fifo1_sready),
        .s_axis_tdata(win_data_out),
        .s_axis_tlast(win_last),
        .m_axis_aclk(clk_vga),          // 100 MHz CLK
        .m_axis_tvalid(fifo1_mvalid),
        .m_axis_tready(fft_sready),
        .m_axis_tdata(fifo1_data_out),
        .m_axis_tlast(fifo1_mlast)
    );
    wire [7:0] fft_config_data;
    assign fft_config_data = 0;
    reg fft_config_valid;
    wire [63:0] fft_mdata;
    wire fft_mvalid, c2p_sready, fft_mlast;
    xfft_0 fft(
        .aclk(clk_vga),
        .aresetn(~RESET),
        .s_axis_config_tdata(fft_config_data),
        .s_axis_config_tvalid(1'b1),
        .s_axis_config_tready(),
        .s_axis_data_tdata({16'b0, fifo1_data_out}),
        .s_axis_data_tvalid(fifo1_mvalid),
        .s_axis_data_tready(fft_sready),
        .s_axis_data_tlast(fifo1_mlast),
        .m_axis_data_tdata(fft_mdata),
        .m_axis_data_tvalid(fft_mvalid),
        .m_axis_data_tready(c2p_sready),
        .m_axis_data_tlast(fft_mlast)
    );
    // LINE OF COMPLETION
    wire [26:0] c2p_mdata;
    wire c2p_mvalid, p2d_sready;
    ComplexToPower c2p(
        .s_axis_tdata(fft_mdata),
        .s_axis_tvalid(fft_mvalid),
        .s_axis_tready(c2p_sready),
        .m_axis_tdata(c2p_mdata),
        .m_axis_tvalid(c2p_mvalid),
        .m_axis_tready(p2d_sready),
        .clk(clk_vga),
        .reset(RESET)
    );
    

endmodule