module top(
    input wire CLK,
    input wire RESET,

    output wire M_CLK,
    input wire M_DATA,      // input from ADMP
    output wire M_LRSEL
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
    
    
    //ila_0 i(
        //.clk(M_CLK),
        
        //.probe0(cic_dataout),
        //.probe1(M_CLK),
        //.probe2(cic_valid)
    //);
    

endmodule