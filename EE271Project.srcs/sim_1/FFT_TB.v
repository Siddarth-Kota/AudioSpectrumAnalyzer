`timescale 1ns / 1ps

module fft1024_tb;

    parameter N = 1024;
    parameter LOGN = 10;
    parameter TONE_BIN = 64;
    parameter ZERO_THRESH = 256;

    reg clk;
    reg rst_n;

    reg signed [15:0] s_data;
    reg s_valid;
    wire s_ready;

    wire [63:0] m_data;
    wire m_valid;
    reg m_ready;

    reg signed [26:0] xr_out [0:N-1];
    reg signed [26:0] xi_out [0:N-1];

    reg signed [15:0] samp_dc [0:N-1];
    reg signed [15:0] samp_tone [0:N-1];

    integer pass_cnt;
    integer fail_cnt;
    integer k_i;
    integer nonzero;
    integer pk;
    real ang_v;

    fft1024 #(
        .N(N),
        .LOGN(LOGN)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .s_data(s_data),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .m_data(m_data),
        .m_valid(m_valid),
        .m_ready(m_ready)
    );

    always #166.67 clk = ~clk;

    task check;
        input cond;
        input [255:0] msg;
        begin
            if (cond) begin
                $display("PASS | %s", msg);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("FAIL | %s", msg);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    task gen_twiddle_mems;
        integer fd_r;
        integer fd_i;
        integer k;
        real angle;
        integer wr_int;
        integer wi_int;
        reg [15:0] wr_bits;
        reg [15:0] wi_bits;
        begin
            fd_r = $fopen("twiddle_real.mem", "w");
            fd_i = $fopen("twiddle_imag.mem", "w");

            if (fd_r == 0 || fd_i == 0) begin
                $display("ERROR: Could not create twiddle mem files.");
                $finish;
            end

            for (k = 0; k < N/2; k = k + 1) begin
                angle = -2.0 * 3.14159265358979323846 * k / N;

                wr_int = $rtoi($cos(angle) * 32767.0);
                wi_int = $rtoi($sin(angle) * 32767.0);

                if (wr_int > 32767) wr_int = 32767;
                if (wr_int < -32768) wr_int = -32768;
                if (wi_int > 32767) wi_int = 32767;
                if (wi_int < -32768) wi_int = -32768;

                wr_bits = wr_int[15:0];
                wi_bits = wi_int[15:0];

                $fwrite(fd_r, "%04h\n", wr_bits);
                $fwrite(fd_i, "%04h\n", wi_bits);
            end

            $fclose(fd_r);
            $fclose(fd_i);

            $display("Twiddle files generated.");
        end
    endtask

    task do_reset;
        begin
            @(negedge clk);
            rst_n = 1'b0;
            s_valid = 1'b0;
            m_ready = 1'b0;
            s_data = 16'sd0;

            repeat (6) @(posedge clk);

            @(negedge clk);
            rst_n = 1'b1;

            @(posedge clk);
        end
    endtask

    task send_dc_frame;
        input integer pause_at;
        input integer pause_len;
        integer i;
        integer p;
        begin
            i = 0;

            while (i < N) begin
                @(negedge clk);

                if (pause_at >= 0 && i == pause_at) begin
                    s_valid = 1'b0;
                    for (p = 0; p < pause_len; p = p + 1)
                        @(posedge clk);
                    @(negedge clk);
                end

                s_data = samp_dc[i];
                s_valid = 1'b1;

                @(posedge clk);

                if (s_ready)
                    i = i + 1;
            end

            @(negedge clk);
            s_valid = 1'b0;
        end
    endtask

    task send_tone_frame;
        input integer pause_at;
        input integer pause_len;
        integer i;
        integer p;
        begin
            i = 0;

            while (i < N) begin
                @(negedge clk);

                if (pause_at >= 0 && i == pause_at) begin
                    s_valid = 1'b0;
                    for (p = 0; p < pause_len; p = p + 1)
                        @(posedge clk);
                    @(negedge clk);
                end

                s_data = samp_tone[i];
                s_valid = 1'b1;

                @(posedge clk);

                if (s_ready)
                    i = i + 1;
            end

            @(negedge clk);
            s_valid = 1'b0;
        end
    endtask

    task collect_output;
        input integer stall_at;
        input integer stall_len;
        integer b;
        integer s;
        reg [63:0] cap;
        begin
            b = 0;
            m_ready = 1'b0;

            @(posedge clk);

            while (!m_valid)
                @(posedge clk);

            while (b < N) begin
                @(negedge clk);

                if (stall_at >= 0 && b == stall_at) begin
                    m_ready = 1'b0;

                    for (s = 0; s < stall_len; s = s + 1)
                        @(posedge clk);

                    @(negedge clk);
                end

                m_ready = 1'b1;

                @(posedge clk);

                if (m_valid && m_ready) begin
                    cap = m_data;

                    xr_out[b] = $signed(cap[26:0]);
                    xi_out[b] = $signed(cap[58:32]);

                    b = b + 1;
                end
            end

            @(negedge clk);
            m_ready = 1'b0;
        end
    endtask

    function [63:0] mag2;
        input signed [26:0] r;
        input signed [26:0] i;
        reg signed [53:0] rsq;
        reg signed [53:0] isq;
        begin
            rsq = r * r;
            isq = i * i;
            mag2 = rsq + isq;
        end
    endfunction

    function [9:0] peak_bin;
        input dummy;
        integer k;
        reg [63:0] best;
        reg [9:0] best_k;
        begin
            best = 64'd0;
            best_k = 10'd0;

            for (k = 0; k < N; k = k + 1) begin
                if (mag2(xr_out[k], xi_out[k]) > best) begin
                    best = mag2(xr_out[k], xi_out[k]);
                    best_k = k[9:0];
                end
            end

            peak_bin = best_k;
        end
    endfunction

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        s_data = 16'sd0;
        s_valid = 1'b0;
        m_ready = 1'b0;
        pass_cnt = 0;
        fail_cnt = 0;

        gen_twiddle_mems();

        #1;
        $readmemh("twiddle_real.mem", dut.wr);
        $readmemh("twiddle_imag.mem", dut.wi);

        for (k_i = 0; k_i < N; k_i = k_i + 1)
            samp_dc[k_i] = 16'sh4000;

        for (k_i = 0; k_i < N; k_i = k_i + 1) begin
            ang_v = 2.0 * 3.14159265358979 * TONE_BIN * k_i / N;
            samp_tone[k_i] = $rtoi($cos(ang_v) * 16383.0);
        end

        $display("---- TC1: DC Input ----");
        do_reset();

        fork
            send_dc_frame(-1, 0);
            collect_output(-1, 0);
        join

        check(mag2(xr_out[0], xi_out[0]) > 64'd1000,
              "TC1: DC bin is large");

        nonzero = 0;
        for (k_i = 1; k_i < N; k_i = k_i + 1) begin
            if (mag2(xr_out[k_i], xi_out[k_i]) > ZERO_THRESH)
                nonzero = nonzero + 1;
        end

        check(nonzero == 0,
              "TC1: Non-DC bins are near zero");

        $display("---- TC2: Single Tone ----");
        do_reset();

        fork
            send_tone_frame(-1, 0);
            collect_output(-1, 0);
        join

        pk = peak_bin(1'b0);

        $display("Peak bin detected: %0d, expected %0d or %0d",
                 pk, TONE_BIN, N - TONE_BIN);

        check((pk == TONE_BIN) || (pk == N - TONE_BIN),
              "TC2: Tone peak is at expected bin");

        $display("---- TC3: Back-to-Back Frames ----");
        do_reset();

        fork
            send_tone_frame(-1, 0);
            collect_output(-1, 0);
        join

        fork
            send_dc_frame(-1, 0);
            collect_output(-1, 0);
        join

        check(mag2(xr_out[0], xi_out[0]) > 64'd1000,
              "TC3: Second DC frame works");

        $display("---- TC4: s_valid Pause ----");
        do_reset();

        fork
            send_dc_frame(100, 10);
            collect_output(-1, 0);
        join

        check(mag2(xr_out[0], xi_out[0]) > 64'd1000,
              "TC4: Works with s_valid pause");

        $display("---- TC5: m_ready Stall ----");
        do_reset();

        fork
            send_dc_frame(-1, 0);
            collect_output(200, 20);
        join

        check(mag2(xr_out[0], xi_out[0]) > 64'd1000,
              "TC5: Works with m_ready stall");

        $display("---- TC6: Reset During Compute ----");
        do_reset();

        send_tone_frame(-1, 0);

        repeat (50) @(posedge clk);

        @(negedge clk);
        rst_n = 1'b0;

        repeat (4) @(posedge clk);

        @(negedge clk);
        rst_n = 1'b1;

        @(posedge clk);

        fork
            send_dc_frame(-1, 0);
            collect_output(-1, 0);
        join

        check(mag2(xr_out[0], xi_out[0]) > 64'd1000,
              "TC6: Works after reset during compute");

        $display("========================================");
        $display("RESULTS: %0d passed, %0d failed", pass_cnt, fail_cnt);
        $display("========================================");

        $finish;
    end

    initial begin
        #50000000;
        $display("FATAL: Simulation timeout.");
        $finish;
    end

endmodule