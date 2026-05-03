`timescale 1ns / 1ps

module fft1024 (
    input clk,
    input rst_n,

    input signed [15:0] sample_in,
    input sample_valid,

    output reg [31:0] fft_out,
    output reg valid_out
);

    parameter N = 1024;
    parameter LOGN = 10;

    // =========================
    // MEMORY
    // =========================
    reg signed [15:0] xr [0:N-1];
    reg signed [15:0] xi [0:N-1];

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

    // =========================
    // TWIDDLES
    // =========================
    reg signed [15:0] wr [0:N/2-1];
    reg signed [15:0] wi [0:N/2-1];

    initial begin
        $readmemh("twiddle_real.mem", wr);
        $readmemh("twiddle_imag.mem", wi);
    end

    // =========================
    // TEMP
    // =========================
    reg signed [15:0] ur, ui, vr, vi;
    reg signed [31:0] tr, ti;

    reg [10:0] span, step;
    reg [10:0] j, k;
    reg [10:0] i1, i2;
    reg [10:0] tw;

    // =========================
    // FSM
    // =========================
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= LOAD;
            load_count <= 0;
            valid_out <= 0;
            stage <= 0;
            index <= 0;
            out_count <= 0;
        end else begin

            case (state)

            // =========================
            // LOAD FRAME
            // =========================
            LOAD: begin
                valid_out <= 0;

                if (sample_valid) begin
                    xr[load_count] <= sample_in;
                    xi[load_count] <= 0;

                    if (load_count == N-1) begin
                        load_count <= 0;
                        stage <= 0;
                        index <= 0;
                        state <= COMPUTE;
                    end else begin
                        load_count <= load_count + 1;
                    end
                end
            end

            // =========================
            // COMPUTE FFT
            // =========================
            COMPUTE: begin
                span <= (1 << (stage + 1));
                step <= (N >> (stage + 1));

                j <= index & ((span >> 1) - 1);
                k <= (index / span) * span;

                i1 <= k + j;
                i2 <= i1 + (span >> 1);

                ur <= xr[i1];
                ui <= xi[i1];
                vr <= xr[i2];
                vi <= xi[i2];

                tw <= j * step;

                tr <= (vr * wr[tw] - vi * wi[tw]) >>> 15;
                ti <= (vr * wi[tw] + vi * wr[tw]) >>> 15;

                //  scaled butterfly (to prevent overflow)
                xr[i1] <= (ur + tr[15:0]) >>> 1;
                xi[i1] <= (ui + ti[15:0]) >>> 1;
                xr[i2] <= (ur - tr[15:0]) >>> 1;
                xi[i2] <= (ui - ti[15:0]) >>> 1;

                if (index == (N >> 1) - 1) begin
                    index <= 0;

                    if (stage == LOGN-1) begin
                        out_count <= 0;
                        state <= OUTPUT;
                    end else begin
                        stage <= stage + 1;
                    end
                end else begin
                    index <= index + 1;
                end
            end

            // =========================
            // OUTPUT
            // =========================
            OUTPUT: begin
                fft_out <= {xr[out_count], xi[out_count]};
                valid_out <= 1;

                if (out_count == N-1) begin
                    state <= LOAD;
                    valid_out <= 0;
                end else begin
                    out_count <= out_count + 1;
                end
            end

            endcase
        end
    end

endmodule