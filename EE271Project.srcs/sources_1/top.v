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
    always @(posedge CLK)
    begin
        clk_div<=~clk_div;
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
        .clk_vga(clk_vga),
        .reset(RESET),
        .locked(),
        .clk_in1(fclk)
    );
    
    always @(posedge clk_mic_raw) begin 
        clk_mic_actual <= ~clk_mic_actual;   // 3 MHz CLK
    end

    // generate CLK and SEL signals to receive PDM data
    mic m(
        .clk(clk_mic_actual),
        .reset(RESET),
        .m_clk(M_CLK),
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
    wire        fir_mvalid, fir_mready;
    assign fir_ready = 1;               // assume window is always ready to accept data
    fir f(
        .data_out(fir_dataout),
        .data_in(cic_dataout),
        .s_valid(cic_mvalid),
        .s_ready(fir_sready),
        .m_valid(fir_mvalid),
        .m_ready(fir_mready),
        .clk(M_CLK),
        .reset(RESET)
    );

    wire [23:0] win_data_out;
    wire        win_mvalid;
    Window win(
        .clk(M_CLK),
        .rst_n(!RESET),
        .audio_data_in(fir_dataout),
        .data_valid_in(fir_mvalid),
        .windowed_data_out(win_data_out),
        .data_valid_out(win_mvalid)
    );

    reg [9:0] win_last_count;    
    always @(posedge M_CLK, posedge RESET) begin 
        if(RESET) begin 
            win_last_count <= 0;
        end
        else if (win_mvalid) begin 
            if(win_last_count == 10'd1023) win_last_count <= 0;
            else win_last_count <= win_last_count + 1;
        end
    end
    wire win_last;
    assign win_last = win_last_count == 10'd1023;
    wire        fifo_mvalid, fifo_mready;
    wire [23:0] fifo_data_out;
    wire        fifo_mlast;
    axis_data_fifo_0 axis_fifo(
        .s_axis_aresetn(!RESET),
        .s_axis_aclk(M_CLK),
        .s_axis_tvalid(win_mvalid),
        .s_axis_tready(1'b1),   // assume FIFO is always ready, may need to fix if FFT stalls
        .s_axis_tdata(win_data_out),
        .s_axis_tlast(win_last),
        .m_axis_tvalid(fifo_mvalid),
        .m_axis_tready(fifo_mready),
        .m_axis_tdata(fifo_data_out),
        .m_axis_tlast(fifo_mlast)
    );
    wire [15:0] fft_config_data = 16'b0000010101010101;     // some constant
    wire [63:0] fft_mdata;
    wire        fft_mvalid, fft_mready, fft_mlast;
    xfft_0 fft(
        .aclk(M_CLK),
        .aresetn(!RESETN),
        .s_axis_config_tdata(fft_config_data),
        .s_axis_config_tvalid(1'b1),
        .s_axis_config_tready(),
        .s_axis_data_tdata(fifo_data_out),
        .s_axis_data_tvalid(fifo_mvalid),
        .s_axis_data_tready(fifo_mready),
        .s_axis_data_tlast(fifo_mlast),
        .m_axis_data_tdata(fft_mdata),
        .m_axis_data_tvalid(fft_mvalid),
        .m_axis_data_tready(fft_mready),
        .m_axis_data_tlast(fft_mlast)
    );
    assign fft_mready = 1'b1;

    wire [26:0] cp_tdata;
    wire        cp_tvalid;
    wire        cp_tready;

    ComplexToPower cp(
        .s_axis_tdata  (fft_mdata),     
        .s_axis_tvalid (fft_mvalid),
        .s_axis_tready (fft_mready),    
        .m_axis_tdata  (cp_tdata),      
        .m_axis_tvalid (cp_tvalid),
        .m_axis_tready (cp_tready),
        .clk           (M_CLK),
        .reset         (RESET)
    );

    wire [6:0] db;
    wire       pd_mvalid;

    PowerToDb pd(
        .s_axis_tdata  (cp_tdata),     
        .s_axis_tvalid (cp_tvalid),
        .s_axis_tready (cp_tready),      e
        .m_axis_tdata  (db),              
        .m_axis_tvalid (pd_mvalid),
        .m_axis_tready (1'b1),           
        .clk           (M_CLK),
        .reset         (RESET)
    );

    vga_display vd(
        .sys_clk(clk_vga),
        .reset(RESET),
        .btn_r(),
        .valid(pd_mvalid),
        .db(db),
        .Hsync(Hsync),
        .Vsync(Vsync),
        .vgaRed(vgaRed),
        .vgaGreen(vgaGreen),
        .vgaBlue(vgaBlue)
    );
    
    
    //ila_0 i(
        //.clk(M_CLK),
        
        //.probe0(cic_dataout),
        //.probe1(M_CLK),
        //.probe2(cic_valid)
    //);
    

endmodule