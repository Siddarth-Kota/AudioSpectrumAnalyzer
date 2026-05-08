`timescale 1ns / 1ps

// ============================================================
// buffer_final - Async FIFO bridge between Window and FFT
//
// Integration notes:
//   1. s_data is now [15:0] to directly accept Window's
//      windowed_data_out without zero-extension at the top level.
//      Internally the buffer zero-pads to 32 bits before storing
//      and forwarding to m_data.
//
//   2. Reset is now active-HIGH on both wr_rst and rd_rst,
//      matching Window's active-high rst convention.
//      Instantiate with:
//          .wr_rst (rst),
//          .rd_rst (rst)
//
//   3. Window does not produce s_last. Tie s_last low at
//      instantiation (.s_last(1'b0)) and rely on GENERATE_LAST=1
//      to auto-generate a last pulse every FRAME_SIZE samples.
//
//   4. The read FSM has a 1-cycle m_valid gap between consecutive
//      output words (inherent to the registered-read pipeline).
//      The downstream FFT must tolerate non-contiguous m_valid
//      and must not assume back-to-back valid cycles within a frame.
// ============================================================

module buffer_final #(
    parameter DEPTH         = 2048,
    parameter ADDR          = 11,
    parameter FRAME_SIZE    = 1024,
    parameter FRAME_BITS    = 10,
    parameter GENERATE_LAST = 1
)(
    // ============================================================
    // Write side clock domain - from Window
    // ============================================================
    input  wire        wr_clk,
    input  wire        wr_rst,   // Active HIGH, matches Window's rst

    // AXI-Stream Slave Interface - from Window
    // s_data is 16-bit to directly accept windowed_data_out.
    // Zero-padded to 32 bits internally before storing.
    // Tie s_last to 1'b0; GENERATE_LAST handles framing.
    input  wire [15:0] s_data,
    input  wire        s_valid,
    output wire        s_ready,
    input  wire        s_last,

    // ============================================================
    // Read side clock domain - to FFT
    // ============================================================
    input  wire        rd_clk,
    input  wire        rd_rst,   // Active HIGH, matches Window's rst

    // AXI-Stream Master Interface - to FFT
    // m_data is 32-bit: upper 16 bits are zero, lower 16 bits are sample.
    output reg  [31:0] m_data,
    output reg         m_valid,
    output reg         m_last,
    input  wire        m_ready
);

    // ============================================================
    // FIFO memory
    //
    // Each word stores:
    //   bit 32    : last flag
    //   bits 31:0 : {16'b0, s_data[15:0]}
    // ============================================================
    reg [32:0] mem [0:DEPTH-1];
    reg [32:0] rd_data_reg;

    // ============================================================
    // Binary to Gray conversion
    // ============================================================
    function [ADDR:0] bin_to_gray;
        input [ADDR:0] bin;
        begin
            bin_to_gray = (bin >> 1) ^ bin;
        end
    endfunction

    // ============================================================
    // Write pointer
    // ============================================================
    reg [ADDR:0] wr_bin;
    reg [ADDR:0] wr_gray;

    wire [ADDR:0] wr_bin_plus1;
    wire [ADDR:0] wr_gray_plus1;

    assign wr_bin_plus1  = wr_bin + 1'b1;
    assign wr_gray_plus1 = bin_to_gray(wr_bin_plus1);

    // ============================================================
    // Read pointer
    // ============================================================
    reg [ADDR:0] rd_bin;
    reg [ADDR:0] rd_gray;

    wire [ADDR:0] rd_bin_plus1;
    wire [ADDR:0] rd_gray_plus1;

    assign rd_bin_plus1  = rd_bin + 1'b1;
    assign rd_gray_plus1 = bin_to_gray(rd_bin_plus1);

    // ============================================================
    // Pointer synchronizers (two-flop CDC)
    // ============================================================
(* ASYNC_REG = "TRUE" *) reg [ADDR:0] wr_gray_sync1_rd;
(* ASYNC_REG = "TRUE" *) reg [ADDR:0] wr_gray_sync2_rd;

(* ASYNC_REG = "TRUE" *) reg [ADDR:0] rd_gray_sync1_wr;
(* ASYNC_REG = "TRUE" *) reg [ADDR:0] rd_gray_sync2_wr;

    // Sync write pointer into read domain
    always @(posedge rd_clk or posedge rd_rst) begin
        if (rd_rst) begin
            wr_gray_sync1_rd <= 0;
            wr_gray_sync2_rd <= 0;
        end else begin
            wr_gray_sync1_rd <= wr_gray;
            wr_gray_sync2_rd <= wr_gray_sync1_rd;
        end
    end

    // Sync read pointer into write domain
    always @(posedge wr_clk or posedge wr_rst) begin
        if (wr_rst) begin
            rd_gray_sync1_wr <= 0;
            rd_gray_sync2_wr <= 0;
        end else begin
            rd_gray_sync1_wr <= rd_gray;
            rd_gray_sync2_wr <= rd_gray_sync1_wr;
        end
    end

    // ============================================================
    // Full logic - write clock domain
    // ============================================================
    reg fifo_full_reg;

    assign s_ready = !fifo_full_reg;

    wire input_fire;
    assign input_fire = s_valid && s_ready;

    wire [ADDR:0] wr_bin_after_write;
    wire [ADDR:0] wr_gray_after_write;

    assign wr_bin_after_write  = wr_bin + input_fire;
    assign wr_gray_after_write = bin_to_gray(wr_bin_after_write);

    wire fifo_full_next;

    assign fifo_full_next =
        (wr_gray_after_write == {
            ~rd_gray_sync2_wr[ADDR:ADDR-1],
             rd_gray_sync2_wr[ADDR-2:0]
        });

    // ============================================================
    // Frame-last generation
    //
    // Window does not output s_last, so s_last is tied to 1'b0
    // at instantiation. With GENERATE_LAST=1 (default), the buffer
    // asserts last every FRAME_SIZE accepted samples so the FFT
    // knows when a full 1024-sample frame has arrived.
    // ============================================================
    reg [FRAME_BITS-1:0] frame_count;

    wire generated_last;
    assign generated_last = (frame_count == FRAME_SIZE - 1);

    wire last_to_store;
    assign last_to_store = s_last | (GENERATE_LAST ? generated_last : 1'b0);

    // ============================================================
    // Input data formatting
    //
    // s_data is 16-bit (windowed_data_out from Window).
    // Zero-padded to 32 bits for FIFO storage and m_data output.
    // ============================================================
    wire [31:0] fifo_data_in;
    assign fifo_data_in = {16'b0, s_data};

    // ============================================================
    // Write logic
    // ============================================================
    always @(posedge wr_clk or posedge wr_rst) begin
        if (wr_rst) begin
            wr_bin        <= 0;
            wr_gray       <= 0;
            fifo_full_reg <= 0;
            frame_count   <= 0;
        end else begin
            if (input_fire) begin
                mem[wr_bin[ADDR-1:0]] <= {last_to_store, fifo_data_in};

                wr_bin  <= wr_bin_plus1;
                wr_gray <= wr_gray_plus1;

                if (last_to_store)
                    frame_count <= 0;
                else
                    frame_count <= frame_count + 1'b1;
            end

            fifo_full_reg <= fifo_full_next;
        end
    end

    // ============================================================
    // Empty logic - read clock domain
    // ============================================================
    wire fifo_empty;
    assign fifo_empty = (rd_gray == wr_gray_sync2_rd);

    // ============================================================
    // Registered read from memory
    // ============================================================
    always @(posedge rd_clk or posedge rd_rst) begin
        if (rd_rst)
            rd_data_reg <= 33'd0;
        else
            rd_data_reg <= mem[rd_bin[ADDR-1:0]];
    end

    wire        rd_last_bit;
    wire [31:0] rd_sample_data;

    assign rd_last_bit    = rd_data_reg[32];
    assign rd_sample_data = rd_data_reg[31:0];

    // ============================================================
    // Read FSM
    //
    // NOTE: Due to the registered memory read, there is a 1-cycle
    // m_valid gap between consecutive output words:
    //   RD_ACTIVE (m_ready=1) → m_valid deasserts for 1 cycle
    //   RD_PENDING             → m_valid reasserts with new data
    //
    // The downstream FFT must handle non-contiguous m_valid.
    // ============================================================
    localparam RD_IDLE    = 2'd0;
    localparam RD_PENDING = 2'd1;
    localparam RD_ACTIVE  = 2'd2;

    reg [1:0] rd_state;

    always @(posedge rd_clk or posedge rd_rst) begin
        if (rd_rst) begin
            rd_bin   <= 0;
            rd_gray  <= 0;
            rd_state <= RD_IDLE;

            m_data   <= 32'd0;
            m_valid  <= 1'b0;
            m_last   <= 1'b0;
        end else begin
            case (rd_state)

                RD_IDLE: begin
                    m_valid <= 1'b0;
                    m_last  <= 1'b0;

                    if (!fifo_empty) begin
                        rd_bin   <= rd_bin_plus1;
                        rd_gray  <= rd_gray_plus1;
                        rd_state <= RD_PENDING;
                    end
                end

                RD_PENDING: begin
                    m_data   <= rd_sample_data;
                    m_last   <= rd_last_bit;
                    m_valid  <= 1'b1;
                    rd_state <= RD_ACTIVE;
                end

                RD_ACTIVE: begin
                    if (m_ready) begin
                        if (!fifo_empty) begin
                            rd_bin   <= rd_bin_plus1;
                            rd_gray  <= rd_gray_plus1;

                            m_valid  <= 1'b0;   // 1-cycle gap; see FSM note above
                            rd_state <= RD_PENDING;
                        end else begin
                            m_valid  <= 1'b0;
                            m_last   <= 1'b0;
                            rd_state <= RD_IDLE;
                        end
                    end
                end

                default: begin
                    rd_state <= RD_IDLE;
                    m_valid  <= 1'b0;
                    m_last   <= 1'b0;
                end

            endcase
        end
    end

endmodule