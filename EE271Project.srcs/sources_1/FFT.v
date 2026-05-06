`timescale 1ns / 1ps

module fft1024 #(
    parameter N    = 1024,
    parameter LOGN = 10
)(
    input  wire        clk,
    input  wire        rst_n,

    // AXI-Stream Slave (from Buffer)
    input  wire signed [15:0] s_data,
    input  wire               s_valid,
    output reg                s_ready,

    // AXI-Stream Master (to ComplexToPower)
    // [26:0]=real(xr), [31:27]=unused, [58:32]=imag(xi), [63:59]=unused
    output reg  [63:0]        m_data,
    output reg                m_valid,
    input  wire               m_ready
);

    // =========================
    // MEMORY
    // =========================
    reg signed [15:0] xr [0:N-1];
    reg signed [15:0] xi [0:N-1];

    // =========================
    // TWIDDLE ROM
    // =========================
    reg signed [15:0] wr [0:N/2-1];
    reg signed [15:0] wi [0:N/2-1];

    initial begin
        $readmemh("twiddle_real.mem", wr);
        $readmemh("twiddle_imag.mem", wi);
    end

    // =========================
    // CONTROL
    // =========================
    reg [9:0] load_count;
    reg [9:0] out_count;
    reg [3:0] stage;
    reg [9:0] index;

    reg [1:0] state;
    localparam LOAD    = 2'd0;
    localparam COMPUTE = 2'd1;
    localparam OUTPUT  = 2'd2;

    reg compute_phase; // 0 = read/multiply, 1 = write butterfly

    // =========================
    // BIT-REVERSE FUNCTION
    // =========================
    function [9:0] bit_rev;
        input [9:0] in;
        integer b;
        begin
            bit_rev = 0;
            for (b = 0; b < LOGN; b = b + 1)
                bit_rev[b] = in[LOGN-1-b];
        end
    endfunction

    // =========================
    // BUTTERFLY PIPELINE REGS
    // =========================
    reg signed [15:0] p_ur, p_ui;
    reg signed [31:0] p_tr, p_ti;
    reg [9:0]         p_i1, p_i2;

    // =========================
    // BUTTERFLY WIDTH EXTENSION
    // 17-bit wires prevent overflow before >>>1 scaling
    // Q15 x Q15 = Q30, slice [30:15] extracts Q15 result
    // Sign-extend to 17 bits before add/subtract
    // =========================
    wire signed [15:0] tr_q15 = p_tr[30:15];
    wire signed [15:0] ti_q15 = p_ti[30:15];

    wire signed [16:0] sum_r  = {p_ur[15], p_ur}  + {tr_q15[15], tr_q15};
    wire signed [16:0] sum_i  = {p_ui[15], p_ui}  + {ti_q15[15], ti_q15};
    wire signed [16:0] diff_r = {p_ur[15], p_ur}  - {tr_q15[15], tr_q15};
    wire signed [16:0] diff_i = {p_ui[15], p_ui}  - {ti_q15[15], ti_q15};

    // =========================
    // INDEX MATH (no division - all shifts and masks)
    // group  = index >> stage        (not stage_plus_1)
    // k_base = group << stage_plus_1
    // Together correctly enumerates all butterfly pairs
    // at every stage without repeats or skips
    // =========================
    wire [3:0] stage_plus_1 = stage + 1;
    wire [9:0] half_span    = 10'd1 << stage;
    wire [9:0] j_idx        = index & (half_span - 10'd1);
    wire [9:0] group        = index >> stage;
    wire [9:0] k_base       = group << stage_plus_1;
    wire [9:0] i1_w         = k_base + j_idx;
    wire [9:0] i2_w         = i1_w + half_span;
    wire [8:0] tw_w         = j_idx << (LOGN - 1 - stage);

    // =========================
    // OUTPUT PACKING FUNCTION
    // real(xr) → [26:0], imag(xi) → [58:32]
    // 16-bit values sign-extended to 27 bits
    // =========================
    function [63:0] pack_output;
        input [9:0] idx;
        begin
            pack_output = {5'b0,
                           {{11{xi[idx][15]}}, xi[idx]},  // [58:32] imag
                           5'b0,
                           {{11{xr[idx][15]}}, xr[idx]}}; // [26:0]  real
        end
    endfunction

    // =========================
    // MAIN FSM
    // =========================
    always @(posedge clk) begin
        if (!rst_n) begin
            state         <= LOAD;
            load_count    <= 0;
            out_count     <= 0;
            stage         <= 0;
            index         <= 0;
            compute_phase <= 0;
            s_ready       <= 1;
            m_valid       <= 0;
            m_data        <= 0;
        end else begin

            case (state)

            // =====================
            // LOAD
            // =====================
            LOAD: begin
                m_valid <= 0;
                s_ready <= 1;  // default high during load

                if (s_valid && s_ready) begin
                    // Bit-reversed write - samples land in correct
                    // order for in-place Cooley-Tukey butterfly
                    xr[bit_rev(load_count)] <= s_data;
                    xi[bit_rev(load_count)] <= 16'sd0;

                    if (load_count == N-1) begin
                        load_count    <= 0;
                        stage         <= 0;
                        index         <= 0;
                        compute_phase <= 0;
                        s_ready       <= 0;  // explicit override - closes window
                                             // before COMPUTE so no stray sample
                                             // can slip through on transition cycle
                        state         <= COMPUTE;
                    end else begin
                        load_count <= load_count + 1;
                    end
                end
            end

            // =====================
            // COMPUTE (2-cycle butterfly)
            // =====================
            COMPUTE: begin
                s_ready <= 0;
                m_valid <= 0;

                if (compute_phase == 0) begin
                    // Cycle 1: read operands, compute twiddle products
                    p_i1 <= i1_w;
                    p_i2 <= i2_w;

                    p_ur <= xr[i1_w];
                    p_ui <= xi[i1_w];

                    // Q15 x Q15 = Q30 (32-bit signed product)
                    p_tr <= ($signed(xr[i2_w]) * $signed(wr[tw_w])
                           - $signed(xi[i2_w]) * $signed(wi[tw_w]));
                    p_ti <= ($signed(xr[i2_w]) * $signed(wi[tw_w])
                           + $signed(xi[i2_w]) * $signed(wr[tw_w]));

                    compute_phase <= 1;

                end else begin
                    // Cycle 2: butterfly write-back
                    // sum/diff are 17-bit - [16:1] is exact
                    // arithmetic right shift by 1, no overflow possible
                    xr[p_i1] <= sum_r[16:1];
                    xi[p_i1] <= sum_i[16:1];
                    xr[p_i2] <= diff_r[16:1];
                    xi[p_i2] <= diff_i[16:1];

                    compute_phase <= 0;

                    if (index == (N >> 1) - 1) begin
                        index <= 0;
                        if (stage == LOGN-1) begin
                            out_count <= 0;
                            state     <= OUTPUT;
                        end else begin
                            stage <= stage + 1;
                        end
                    end else begin
                        index <= index + 1;
                    end
                end
            end

            // =====================
            // OUTPUT
            // =====================
            // Three clearly separated cases:
            //   !m_valid             → first entry, present bin 0
            //   m_valid && m_ready   → handshake fired, load next bin
            //   m_valid && !m_ready  → downstream stalling, hold steady
            // =====================
            OUTPUT: begin
                s_ready <= 0;

                if (m_valid && m_ready) begin
                    // Handshake fired this cycle
                    if (out_count == N-1) begin
                        // Last bin accepted - return to LOAD
                        m_valid   <= 0;
                        s_ready   <= 1;
                        out_count <= 0;
                        state     <= LOAD;
                    end else begin
                        // Load next bin immediately so it is
                        // stable by next cycle's handshake check
                        out_count <= out_count + 1;
                        m_data    <= pack_output(out_count + 1);
                        m_valid   <= 1;
                    end
                end else if (!m_valid) begin
                    // First entry into OUTPUT - present bin 0
                    m_data  <= pack_output(out_count);
                    m_valid <= 1;
                end
                // m_valid && !m_ready: hold, do nothing

            end

            endcase
        end
    end

endmodule