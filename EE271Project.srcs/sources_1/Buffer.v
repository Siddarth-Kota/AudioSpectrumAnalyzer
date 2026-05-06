
`timescale 1ns / 1ps

module buffer_final #(
    parameter N     = 1024,
    parameter WIDTH = 16
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // AXI-Stream Slave (from Window)
    input  wire signed [WIDTH-1:0] s_data,
    input  wire                    s_valid,
    output wire                    s_ready,

    // AXI-Stream Master (to FFT)
    output reg  signed [WIDTH-1:0] m_data,
    output reg                     m_valid,
    input  wire                    m_ready
);

    // =========================
    // DOUBLE BUFFER MEMORY
    // =========================
    reg signed [WIDTH-1:0] mem0 [0:N-1];
    reg signed [WIDTH-1:0] mem1 [0:N-1];

    // =========================
    // POINTERS & STATE
    // =========================
    reg [9:0] write_ptr;
    reg [9:0] read_ptr;

    reg write_sel;   // which buffer is being written: 0=mem0, 1=mem1
    reg read_sel;    // which buffer is being read:    0=mem0, 1=mem1

    // Full flags - only set by write logic, only cleared by read logic
    // To avoid multi-driver, we use a single always block below
    reg buf_full [0:1];   // buf_full[0] = mem0 full, buf_full[1] = mem1 full

    reg reading;  // read side is actively streaming to FFT

    // =========================
    // READY / BACKPRESSURE
    // =========================
    // s_ready: safe to accept from Window as long as the buffer we'd
    // write into isn't full (i.e. not both buffers occupied)
    // If both are full, stall the Window block
    assign s_ready = !(buf_full[0] && buf_full[1]);

    // =========================
    // WRITE LOGIC
    // =========================
    always @(posedge clk) begin
        if (!rst_n) begin
            write_ptr  <= 0;
            write_sel  <= 0;
        end else begin
            if (s_valid && s_ready) begin  // AXI handshake on input

                if (write_sel == 0)
                    mem0[write_ptr] <= s_data;
                else
                    mem1[write_ptr] <= s_data;

                if (write_ptr == N-1) begin
                    write_ptr <= 0;
                    write_sel <= ~write_sel; // ping-pong to other buffer
                end else begin
                    write_ptr <= write_ptr + 1;
                end
            end
        end
    end

    // =========================
    // FULL FLAG LOGIC
    // =========================
    // Consolidated into one always block to avoid multi-driver conflict
    always @(posedge clk) begin
        if (!rst_n) begin
            buf_full[0] <= 0;
            buf_full[1] <= 0;
        end else begin
            // SET: when write finishes filling a buffer
            if (s_valid && s_ready && write_ptr == N-1) begin
                buf_full[write_sel] <= 1;
            end

            // CLEAR: when read side finishes draining a buffer
            // read_ptr hits N-1 and FFT accepts the last sample
            if (reading && m_ready && read_ptr == N-1) begin
                buf_full[read_sel] <= 0;
            end
        end
    end

    // =========================
    // READ / OUTPUT LOGIC
    // =========================
    always @(posedge clk) begin
        if (!rst_n) begin
            reading   <= 0;
            read_ptr  <= 0;
            read_sel  <= 0;
            m_valid   <= 0;
            m_data    <= 0;
        end else begin

            if (!reading) begin
                m_valid <= 0;
                // Start reading whichever buffer is full
                // Priority to buf 0; buf 1 if only that is full
                if (buf_full[0]) begin
                    reading  <= 1;
                    read_sel <= 0;
                    read_ptr <= 0;
                end else if (buf_full[1]) begin
                    reading  <= 1;
                    read_sel <= 1;
                    read_ptr <= 0;
                end
            end else begin
                // Drive output - data is presented every cycle,
                // but pointer only advances when FFT accepts (m_ready)
                m_valid <= 1;

                if (read_sel == 0)
                    m_data <= mem0[read_ptr];
                else
                    m_data <= mem1[read_ptr];

                if (m_ready) begin  // FFT is accepting this sample
                    if (read_ptr == N-1) begin
                        // Last sample just accepted - done reading
                        reading <= 0;
                        m_valid <= 0;
                    end else begin
                        read_ptr <= read_ptr + 1;
                    end
                end
            end
        end
    end

endmodule