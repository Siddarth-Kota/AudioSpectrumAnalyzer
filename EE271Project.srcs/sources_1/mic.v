module mic(
    input wire      clk,
    input wire      reset,

    output wire     valid,
    output wire     m_clk,
    output wire     m_lrsel 
);
    assign valid = 1;
    assign m_clk = clk;
    // reg lrsel;
    // always @(posedge clk, posedge reset) begin
        // if(reset) lrsel <= 0;
        // lrsel <= 0; 
    // end
    // always @(negedge clk) begin 
        // lrsel <= 1;
    // end
    // assign m_lrsel = lrsel;
    assign m_lrsel = 0;         // who needs the sound in the other ear anyway, samples on posedge
endmodule