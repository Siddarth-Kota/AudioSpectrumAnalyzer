`timescale 1ns / 1ps

module buffer_final #(
    parameter N = 1024,
    parameter WIDTH = 16
)(
    input clk,
    input rst_n,

    // From Window block
    input signed [WIDTH-1:0] windowed_data,
    input window_valid,

    // To FFT
    output reg signed [WIDTH-1:0] data_out,
    output reg data_valid
);

    // =========================
    // DOUBLE BUFFER MEMORY
    // =========================
    reg signed [WIDTH-1:0] mem0 [0:N-1];
    reg signed [WIDTH-1:0] mem1 [0:N-1];

    reg write_sel; // 0 = mem0, 1 = mem1
    reg read_sel;

    reg [9:0] write_ptr;
    reg [9:0] read_ptr;

    reg buffer_full_0;
    reg buffer_full_1;

    reg reading;

    // =========================
    // WRITE LOGIC (ALWAYS ACTIVE)
    // =========================
    always @(posedge clk) begin
        if (!rst_n) begin
            write_ptr <= 0;
            write_sel <= 0;
            buffer_full_0 <= 0;
            buffer_full_1 <= 0;
        end else begin
            if (window_valid) begin
                if (write_sel == 0) begin
                    mem0[write_ptr] <= windowed_data;
                end else begin
                    mem1[write_ptr] <= windowed_data;
                end

                if (write_ptr == N-1) begin
                    write_ptr <= 0;

                    if (write_sel == 0)
                        buffer_full_0 <= 1;
                    else
                        buffer_full_1 <= 1;

                    write_sel <= ~write_sel; // switch buffer
                end else begin
                    write_ptr <= write_ptr + 1;
                end
            end
        end
    end

    // =========================
    // READ CONTROL
    // =========================
    always @(posedge clk) begin
        if (!rst_n) begin
            reading <= 0;
            read_ptr <= 0;
            read_sel <= 0;
            data_valid <= 0;
        end else begin

            // Start reading when a buffer is full
            if (!reading) begin
                if (buffer_full_0) begin
                    reading <= 1;
                    read_sel <= 0;
                    read_ptr <= 0;
                    buffer_full_0 <= 0;
                end else if (buffer_full_1) begin
                    reading <= 1;
                    read_sel <= 1;
                    read_ptr <= 0;
                    buffer_full_1 <= 0;
                end
            end

            // READ ACTIVE
            if (reading) begin
                data_valid <= 1;

                if (read_sel == 0)
                    data_out <= mem0[read_ptr];
                else
                    data_out <= mem1[read_ptr];

                if (read_ptr == N-1) begin
                    reading <= 0;
                    data_valid <= 0;
                end else begin
                    read_ptr <= read_ptr + 1;
                end
            end else begin
                data_valid <= 0;
            end
        end
    end

endmodule