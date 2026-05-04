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
    reg clk_mic_actual;
    clk_wiz_0 clk0(
        .clk_mic(clk_mic_raw),  // 6 MHz CLK 
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
    //ila_0 i(
        //.clk(M_CLK),
        
        //.probe0(cic_dataout),
        //.probe1(M_CLK),
        //.probe2(cic_valid)
    //);
    

endmodule