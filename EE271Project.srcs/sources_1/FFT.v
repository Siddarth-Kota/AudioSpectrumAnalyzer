`timescale 1ns / 1ps

module fft1024 #(
    parameter N    = 1024,
    parameter LOGN = 10
)(
    input  wire        clk,
    input  wire        rst_n,     // active-low reset

    // ============================================================
    // AXI-style Slave Interface, from Buffer
    // ============================================================
    input  wire [31:0] s_data,    // lower 16 bits used
    input  wire        s_valid,
    output reg         s_ready,
    input  wire        s_last,

    // ============================================================
    // AXI-style Master Interface, to ComplexToPower
    // ============================================================
    output reg  [63:0] m_data,
    output reg         m_valid,
    input  wire        m_ready,
    output reg         m_last
);

    // ============================================================
    // Internal FFT storage
    // ============================================================
    reg signed [15:0] xr [0:N-1];
    reg signed [15:0] xi [0:N-1];

    // ============================================================
    // Twiddle ROM
    //
    // For a 1024-point FFT, each file needs 512 signed Q15 entries.
    // ============================================================
    reg signed [15:0] wr [0:N/2-1];
    reg signed [15:0] wi [0:N/2-1];

    initial begin
        $readmemh("twiddle_real.mem", wr);
        $readmemh("twiddle_imag.mem", wi);
    end

    // ============================================================
    // FSM states
    // ============================================================
    localparam LOAD    = 2'd0;
    localparam COMPUTE = 2'd1;
    localparam OUTPUT  = 2'd2;

    reg [1:0] state;

    reg [9:0] load_count;
    reg [9:0] out_count;
    reg [3:0] stage;
    reg [9:0] index;

    reg compute_phase;

    // ============================================================
    // Bit reversal
    // ============================================================
    function [9:0] bit_rev;
        input [9:0] in;
        integer b;
        begin
            bit_rev = 10'd0;
            for (b = 0; b < LOGN; b = b + 1) begin
                bit_rev[b] = in[LOGN-1-b];
            end
        end
    endfunction

    // ============================================================
    // Butterfly index math
    // ============================================================
    wire [3:0] stage_plus_1;
    wire [3:0] tw_shift;

    wire [9:0] half_span;
    wire [9:0] j_idx;
    wire [9:0] group;
    wire [9:0] k_base;

    wire [9:0] i1_w;
    wire [9:0] i2_w;
    wire [8:0] tw_w;

    assign stage_plus_1 = stage + 1'b1;
    assign tw_shift     = LOGN - 1 - stage;

    assign half_span = 10'd1 << stage;
    assign j_idx     = index & (half_span - 10'd1);
    assign group     = index >> stage;
    assign k_base    = group << stage_plus_1;

    assign i1_w = k_base + j_idx;
    assign i2_w = i1_w + half_span;

    assign tw_w = j_idx << tw_shift;

    // ============================================================
    // Butterfly pipeline registers
    // ============================================================
    reg signed [15:0] p_ur;
    reg signed [15:0] p_ui;

    reg signed [32:0] p_tr;
    reg signed [32:0] p_ti;

    reg [9:0] p_i1;
    reg [9:0] p_i2;

    // ============================================================
    // Complex multiply:
    //
    // t = x[i2] * W
    //
    // t_real = xr[i2] * wr - xi[i2] * wi
    // t_imag = xr[i2] * wi + xi[i2] * wr
    // ============================================================
    wire signed [31:0] mult_xr_wr;
    wire signed [31:0] mult_xi_wi;
    wire signed [31:0] mult_xr_wi;
    wire signed [31:0] mult_xi_wr;

    assign mult_xr_wr = $signed(xr[i2_w]) * $signed(wr[tw_w]);
    assign mult_xi_wi = $signed(xi[i2_w]) * $signed(wi[tw_w]);
    assign mult_xr_wi = $signed(xr[i2_w]) * $signed(wi[tw_w]);
    assign mult_xi_wr = $signed(xi[i2_w]) * $signed(wr[tw_w]);

    wire signed [32:0] twiddle_real_calc;
    wire signed [32:0] twiddle_imag_calc;

    assign twiddle_real_calc = {mult_xr_wr[31], mult_xr_wr}
                             - {mult_xi_wi[31], mult_xi_wi};

    assign twiddle_imag_calc = {mult_xr_wi[31], mult_xr_wi}
                             + {mult_xi_wr[31], mult_xi_wr};

    // Q30 back to Q15
    wire signed [32:0] tr_shifted;
    wire signed [32:0] ti_shifted;

    assign tr_shifted = p_tr >>> 15;
    assign ti_shifted = p_ti >>> 15;

    wire signed [15:0] tr_q15;
    wire signed [15:0] ti_q15;

    assign tr_q15 = tr_shifted[15:0];
    assign ti_q15 = ti_shifted[15:0];

    // ============================================================
    // Butterfly add/subtract
    //
    // This FFT divides by 2 at every stage to prevent overflow.
    // Final result is scaled by 1/1024.
    // ============================================================
    wire signed [16:0] sum_r;
    wire signed [16:0] sum_i;
    wire signed [16:0] diff_r;
    wire signed [16:0] diff_i;

    assign sum_r  = {p_ur[15], p_ur} + {tr_q15[15], tr_q15};
    assign sum_i  = {p_ui[15], p_ui} + {ti_q15[15], ti_q15};

    assign diff_r = {p_ur[15], p_ur} - {tr_q15[15], tr_q15};
    assign diff_i = {p_ui[15], p_ui} - {ti_q15[15], ti_q15};

    // ============================================================
    // Output packing for unchanged ComplexToPower block
    //
    // ComplexToPower expects:
    //   real = s_axis_tdata[26:0]
    //   imag = s_axis_tdata[58:32]
    //
    // Therefore:
    //   m_data[26:0]  = real, sign-extended to 27 bits
    //   m_data[31:27] = unused zero padding
    //   m_data[58:32] = imag, sign-extended to 27 bits
    //   m_data[63:59] = unused zero padding
    // ============================================================
    function [63:0] pack_complex;
        input signed [15:0] real_in;
        input signed [15:0] imag_in;
        begin
            pack_complex = {
                5'b0,
                {{11{imag_in[15]}}, imag_in},
                5'b0,
                {{11{real_in[15]}}, real_in}
            };
        end
    endfunction

    wire [9:0] out_count_next;
    assign out_count_next = out_count + 10'd1;

    // ============================================================
    // Main FSM
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= LOAD;

            load_count    <= 10'd0;
            out_count     <= 10'd0;
            stage         <= 4'd0;
            index         <= 10'd0;
            compute_phase <= 1'b0;

            s_ready       <= 1'b1;

            m_data        <= 64'd0;
            m_valid       <= 1'b0;
            m_last        <= 1'b0;

            p_ur          <= 16'sd0;
            p_ui          <= 16'sd0;
            p_tr          <= 33'sd0;
            p_ti          <= 33'sd0;
            p_i1          <= 10'd0;
            p_i2          <= 10'd0;
        end else begin
            case (state)

                // ====================================================
                // LOAD
                // Accepts 1024 samples from the buffer.
                // Data is accepted only when s_valid && s_ready.
                // ====================================================
                LOAD: begin
                    s_ready <= 1'b1;
                    m_valid <= 1'b0;
                    m_last  <= 1'b0;

                    if (s_valid && s_ready) begin
                        `ifndef SYNTHESIS
                        if ((load_count == N-1) && !s_last) begin
                            $display("WARNING: FFT expected s_last on final input sample at time %0t", $time);
                        end

                        if ((load_count != N-1) && s_last) begin
                            $display("WARNING: FFT received early s_last at sample %0d, time %0t",
                                     load_count, $time);
                        end
                        `endif

                        xr[bit_rev(load_count)] <= $signed(s_data[15:0]);
                        xi[bit_rev(load_count)] <= 16'sd0;

                        if (load_count == N-1) begin
                            load_count    <= 10'd0;
                            stage         <= 4'd0;
                            index         <= 10'd0;
                            compute_phase <= 1'b0;

                            s_ready       <= 1'b0;
                            state         <= COMPUTE;
                        end else begin
                            load_count <= load_count + 10'd1;
                        end
                    end
                end

                // ====================================================
                // COMPUTE
                // Two cycles per butterfly.
                // The FFT does not accept input while computing.
                // ====================================================
                COMPUTE: begin
                    s_ready <= 1'b0;
                    m_valid <= 1'b0;
                    m_last  <= 1'b0;

                    if (compute_phase == 1'b0) begin
                        p_i1 <= i1_w;
                        p_i2 <= i2_w;

                        p_ur <= xr[i1_w];
                        p_ui <= xi[i1_w];

                        p_tr <= twiddle_real_calc;
                        p_ti <= twiddle_imag_calc;

                        compute_phase <= 1'b1;
                    end else begin
                        xr[p_i1] <= sum_r[16:1];
                        xi[p_i1] <= sum_i[16:1];

                        xr[p_i2] <= diff_r[16:1];
                        xi[p_i2] <= diff_i[16:1];

                        compute_phase <= 1'b0;

                        if (index == ((N >> 1) - 1)) begin
                            index <= 10'd0;

                            if (stage == LOGN-1) begin
                                out_count <= 10'd0;
                                state     <= OUTPUT;
                            end else begin
                                stage <= stage + 4'd1;
                            end
                        end else begin
                            index <= index + 10'd1;
                        end
                    end
                end

                // ====================================================
                // OUTPUT
                // Sends 1024 FFT bins to ComplexToPower.
                // Data is transferred only when m_valid && m_ready.
                // Holds m_data, m_valid, and m_last steady under
                // downstream backpressure.
                // ====================================================
                OUTPUT: begin
                    s_ready <= 1'b0;

                    if (!m_valid) begin
                        m_data  <= pack_complex(xr[out_count], xi[out_count]);
                        m_valid <= 1'b1;
                        m_last  <= (out_count == N-1);
                    end else if (m_valid && m_ready) begin
                        if (out_count == N-1) begin
                            m_valid   <= 1'b0;
                            m_last    <= 1'b0;
                            m_data    <= 64'd0;
                            out_count <= 10'd0;

                            s_ready   <= 1'b1;
                            state     <= LOAD;
                        end else begin
                            out_count <= out_count_next;
                            m_data    <= pack_complex(xr[out_count_next], xi[out_count_next]);
                            m_valid   <= 1'b1;
                            m_last    <= (out_count_next == N-1);
                        end
                    end
                end

                default: begin
                    state         <= LOAD;

                    load_count    <= 10'd0;
                    out_count     <= 10'd0;
                    stage         <= 4'd0;
                    index         <= 10'd0;
                    compute_phase <= 1'b0;

                    s_ready       <= 1'b1;

                    m_data        <= 64'd0;
                    m_valid       <= 1'b0;
                    m_last        <= 1'b0;
                end

            endcase
        end
    end

endmodule