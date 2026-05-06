module ComplexToPower (

    input wire [63:0] s_axis_tdata, //note this is assuming vivado fft block in unscaled mode, lmk if we use scaled 
    input wire s_axis_tvalid,
    output wire s_axis_tready,


    output reg  [26:0] m_axis_tdata,
    output reg         m_axis_tvalid,
    input  wire        m_axis_tready,



    input wire clk,
    input wire reset
);
    wire [26:0] re = s_axis_tdata[26:0];
    wire [26:0] im = s_axis_tdata[58:32];
    // assuming 
    // real part = bits [26:0]
    // imag part = bits [58:32]

    wire [26:0] abs_re = re[26] ? -re : re; //turns out fft output is in 2's complement, so we need to take the absolute value
    wire [26:0] abs_im = im[26] ? -im : im;

    wire [26:0] mag_next;

    assign mag_next = (abs_re > abs_im) ? abs_re : abs_im;


    assign s_axis_tready = !m_axis_tvalid || m_axis_tready;


     always @(posedge clk or posedge reset) begin
        if (reset) begin
            m_axis_tdata  <= 27'd0;
            m_axis_tvalid <= 1'b0;
        end else begin
            if (s_axis_tready) begin
                m_axis_tvalid <= s_axis_tvalid;

                if (s_axis_tvalid) begin
                    m_axis_tdata <= mag_next;
                end
            end
        end
    end
   



endmodule