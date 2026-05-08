`timescale 1ns / 1ps

module tb_fft1024;

    localparam N = 1024;

    // Simulation-only fast clock:
    // Period = 0.01 ns = 10 ps.
    // This lets the whole testbench finish inside Vivado's default 1000 ns run.
    localparam MAX_WAIT_CYCLES = 50000;

    reg clk;
    reg rst;

    reg  [31:0] s_data;
    reg         s_valid;
    wire        s_ready;
    reg         s_last;

    wire [63:0] m_data;
    wire        m_valid;
    reg         m_ready;
    wire        m_last;

    reg signed [15:0] sample_mem [0:N-1];

    integer out_re [0:N-1];
    integer out_im [0:N-1];

    integer re_a [0:N-1];
    integer im_a [0:N-1];

    integer error_count;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    fft1024 dut (
        .clk     (clk),
        .rst     (rst),

        .s_data  (s_data),
        .s_valid (s_valid),
        .s_ready (s_ready),
        .s_last  (s_last),

        .m_data  (m_data),
        .m_valid (m_valid),
        .m_ready (m_ready),
        .m_last  (m_last)
    );

    // ------------------------------------------------------------
    // Fast simulation clock
    // 0.005 ns high + 0.005 ns low = 0.01 ns period
    // ------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #0.005 clk = ~clk;
    end

    // ------------------------------------------------------------
    // Watchdog
    // If the testbench does not finish before 950 ns, something
    // is probably stuck.
    // ------------------------------------------------------------
    initial begin
        #950;
        $display("");
        $display("==================================================");
        $display("ERROR: Simulation watchdog timeout at 950 ns.");
        $display("The FFT testbench did not finish. Something may be stuck.");
        $display("==================================================");
        $finish;
    end

    // ------------------------------------------------------------
    // Helper functions
    // ------------------------------------------------------------
    function signed [31:0] sx27;
        input [26:0] x;
        begin
            sx27 = {{5{x[26]}}, x};
        end
    endfunction

    function integer abs_int;
        input integer x;
        begin
            if (x < 0)
                abs_int = -x;
            else
                abs_int = x;
        end
    endfunction

    function integer max_int;
        input integer a;
        input integer b;
        begin
            if (a > b)
                max_int = a;
            else
                max_int = b;
        end
    endfunction

    // ------------------------------------------------------------
    // Clear input samples
    // ------------------------------------------------------------
    task clear_samples;
        integer i;
        begin
            for (i = 0; i < N; i = i + 1)
                sample_mem[i] = 16'sd0;
        end
    endtask

    // ------------------------------------------------------------
    // Send one 1024-sample frame into FFT
    // ------------------------------------------------------------
    task send_frame;
        integer i;
        integer wait_count;
        begin : SEND_FRAME_BODY
            for (i = 0; i < N; i = i + 1) begin
                @(negedge clk);

                wait_count = 0;
                while (!s_ready) begin
                    @(negedge clk);
                    wait_count = wait_count + 1;

                    if (wait_count > MAX_WAIT_CYCLES) begin
                        $display("ERROR: Timeout waiting for s_ready while sending sample %0d.", i);
                        error_count = error_count + 1;
                        s_data  = 32'd0;
                        s_valid = 1'b0;
                        s_last  = 1'b0;
                        disable SEND_FRAME_BODY;
                    end
                end

                s_data  = {16'd0, sample_mem[i]};
                s_valid = 1'b1;
                s_last  = (i == N-1);
            end

            @(negedge clk);
            s_data  = 32'd0;
            s_valid = 1'b0;
            s_last  = 1'b0;
        end
    endtask

    // ------------------------------------------------------------
    // Collect 1024 FFT output bins with m_ready high
    // ------------------------------------------------------------
    task collect_outputs;
        integer bin;
        integer wait_count;
        begin : COLLECT_OUTPUTS_BODY
            bin = 0;
            wait_count = 0;
            m_ready = 1'b1;

            while (bin < N) begin
                @(negedge clk);

                wait_count = wait_count + 1;

                if (wait_count > MAX_WAIT_CYCLES) begin
                    $display("ERROR: Timeout waiting for FFT outputs. Collected only %0d bins.", bin);
                    error_count = error_count + 1;
                    disable COLLECT_OUTPUTS_BODY;
                end

                if (m_valid && m_ready) begin
                    out_re[bin] = sx27(m_data[26:0]);
                    out_im[bin] = sx27(m_data[58:32]);

                    if ((bin == N-1) && !m_last) begin
                        $display("ERROR: Expected m_last on final output bin.");
                        error_count = error_count + 1;
                    end

                    if ((bin != N-1) && m_last) begin
                        $display("ERROR: m_last came early at bin %0d.", bin);
                        error_count = error_count + 1;
                    end

                    bin = bin + 1;
                end
            end
        end
    endtask

    // ------------------------------------------------------------
    // Collect outputs while applying output backpressure
    // ------------------------------------------------------------
    task collect_outputs_with_backpressure;
        integer bin;
        integer cycle_count;
        integer stall_count;
        integer wait_count;

        reg [63:0] held_data;
        reg        held_last;
        reg        stalled_prev;

        begin : BACKPRESSURE_BODY
            $display("");
            $display("Checking backpressure with cycle-based m_ready stalls...");

            bin          = 0;
            cycle_count  = 0;
            stall_count  = 0;
            wait_count   = 0;
            stalled_prev = 1'b0;
            held_data    = 64'd0;
            held_last    = 1'b0;

            m_ready = 1'b1;

            while (bin < N) begin
                @(negedge clk);

                wait_count = wait_count + 1;

                if (wait_count > MAX_WAIT_CYCLES) begin
                    $display("ERROR: Timeout during backpressure test. Collected only %0d bins.", bin);
                    error_count = error_count + 1;
                    m_ready = 1'b1;
                    disable BACKPRESSURE_BODY;
                end

                if (stalled_prev) begin
                    if (m_valid !== 1'b1) begin
                        $display("ERROR backpressure: m_valid dropped while stalled at bin %0d.", bin);
                        error_count = error_count + 1;
                    end

                    if (m_data !== held_data) begin
                        $display("ERROR backpressure: m_data changed while stalled at bin %0d.", bin);
                        error_count = error_count + 1;
                    end

                    if (m_last !== held_last) begin
                        $display("ERROR backpressure: m_last changed while stalled at bin %0d.", bin);
                        error_count = error_count + 1;
                    end
                end

                // Stall every third observed output-valid cycle.
                // This uses cycle_count, not bin number, to avoid deadlock.
                if (m_valid && ((cycle_count % 3) == 0))
                    m_ready = 1'b0;
                else
                    m_ready = 1'b1;

                if (m_valid && m_ready) begin
                    out_re[bin] = sx27(m_data[26:0]);
                    out_im[bin] = sx27(m_data[58:32]);

                    if ((bin == N-1) && !m_last) begin
                        $display("ERROR backpressure: expected m_last on final bin.");
                        error_count = error_count + 1;
                    end

                    if ((bin != N-1) && m_last) begin
                        $display("ERROR backpressure: m_last came early at bin %0d.", bin);
                        error_count = error_count + 1;
                    end

                    stalled_prev = 1'b0;
                    bin = bin + 1;
                end else if (m_valid && !m_ready) begin
                    held_data    = m_data;
                    held_last    = m_last;
                    stalled_prev = 1'b1;
                    stall_count  = stall_count + 1;
                end else begin
                    stalled_prev = 1'b0;
                end

                cycle_count = cycle_count + 1;
            end

            m_ready = 1'b1;
            $display("  Backpressure stall cycles applied: %0d", stall_count);
        end
    endtask

    // ------------------------------------------------------------
    // Print selected bins
    // ------------------------------------------------------------
    task print_some_bins;
        integer i;
        begin
            $display("First 16 bins:");
            for (i = 0; i < 16; i = i + 1) begin
                $display("  bin %4d: re = %0d, im = %0d", i, out_re[i], out_im[i]);
            end

            $display("  bin 1019: re = %0d, im = %0d", out_re[1019], out_im[1019]);
            $display("  bin 1023: re = %0d, im = %0d", out_re[1023], out_im[1023]);
        end
    endtask

    // ------------------------------------------------------------
    // Check impulse response
    //
    // Input:
    //   x[0] = 16384
    //   all others = 0
    //
    // Expected:
    //   all bins real ~= 16
    //   all bins imag ~= 0
    // ------------------------------------------------------------
    task check_impulse;
        integer i;
        begin
            $display("");
            $display("Checking impulse response...");

            for (i = 0; i < N; i = i + 1) begin
                if ((out_re[i] < 15) || (out_re[i] > 17) ||
                    (out_im[i] < -1) || (out_im[i] > 1)) begin

                    $display("ERROR impulse bin %0d: re=%0d im=%0d, expected re about 16 and im about 0.",
                             i, out_re[i], out_im[i]);
                    error_count = error_count + 1;
                end
            end
        end
    endtask

    // ------------------------------------------------------------
    // Check DC response
    //
    // Input:
    //   x[n] = 1024
    //
    // Expected:
    //   bin 0 real ~= 1024
    //   other bins near 0
    // ------------------------------------------------------------
    task check_dc;
        integer i;
        integer mag;
        begin
            $display("");
            $display("Checking DC response...");

            if ((out_re[0] < 1000) || (out_re[0] > 1030) ||
                (out_im[0] < -5)   || (out_im[0] > 5)) begin

                $display("ERROR DC bin 0: re=%0d im=%0d, expected re about 1024 and im about 0.",
                         out_re[0], out_im[0]);
                error_count = error_count + 1;
            end

            for (i = 1; i < N; i = i + 1) begin
                mag = max_int(abs_int(out_re[i]), abs_int(out_im[i]));

                if (mag > 30) begin
                    $display("ERROR DC bin %0d: re=%0d im=%0d, expected near 0 with tolerance 30.",
                             i, out_re[i], out_im[i]);
                    error_count = error_count + 1;
                end
            end
        end
    endtask

    // ------------------------------------------------------------
    // Check cosine response at bin 5
    //
    // Input:
    //   x[n] = 12000*cos(2*pi*5*n/1024)
    //
    // Expected:
    //   large peak at bin 5
    //   large peak at bin 1019
    // ------------------------------------------------------------
    task check_cosine_bin5;
        integer i;
        integer mag;
        begin
            $display("");
            $display("Checking cosine bin-5 response...");
            $display("  bin    5: re=%0d im=%0d", out_re[5], out_im[5]);
            $display("  bin 1019: re=%0d im=%0d", out_re[1019], out_im[1019]);

            if (max_int(abs_int(out_re[5]), abs_int(out_im[5])) < 5000) begin
                $display("ERROR: Expected large peak at bin 5.");
                error_count = error_count + 1;
            end

            if (max_int(abs_int(out_re[1019]), abs_int(out_im[1019])) < 5000) begin
                $display("ERROR: Expected large peak at bin 1019.");
                error_count = error_count + 1;
            end

            for (i = 0; i < N; i = i + 1) begin
                if ((i != 5) && (i != 1019)) begin
                    mag = max_int(abs_int(out_re[i]), abs_int(out_im[i]));

                    if (mag > 1000) begin
                        $display("WARNING cosine bin %0d larger than expected: re=%0d im=%0d",
                                 i, out_re[i], out_im[i]);
                    end
                end
            end
        end
    endtask

    // ------------------------------------------------------------
    // Check two consecutive frames
    //
    // This checks that the FFT returns cleanly to LOAD and produces
    // the same result for identical back-to-back frames.
    // ------------------------------------------------------------
    task check_consecutive_frames;
        integer i;
        integer mismatch;
        begin
            $display("");
            $display("Checking consecutive frames...");

            mismatch = 0;

            fork
                send_frame();
                collect_outputs();
            join

            for (i = 0; i < N; i = i + 1) begin
                re_a[i] = out_re[i];
                im_a[i] = out_im[i];
            end

            fork
                send_frame();
                collect_outputs();
            join

            for (i = 0; i < N; i = i + 1) begin
                if ((out_re[i] !== re_a[i]) || (out_im[i] !== im_a[i])) begin
                    $display("ERROR consecutive-frame mismatch at bin %0d: frame A re=%0d im=%0d, frame B re=%0d im=%0d",
                             i, re_a[i], im_a[i], out_re[i], out_im[i]);

                    error_count = error_count + 1;
                    mismatch = mismatch + 1;

                    if (mismatch >= 5) begin
                        $display("  Suppressing further consecutive-frame mismatch messages.");
                        i = N;
                    end
                end
            end

            if (mismatch == 0)
                $display("  Consecutive frames match.");
        end
    endtask

    // ------------------------------------------------------------
    // Main simulation
    // ------------------------------------------------------------
    integer i;
    real PI;

    initial begin
        PI = 3.14159265358979323846;

        error_count = 0;

        s_data  = 32'd0;
        s_valid = 1'b0;
        s_last  = 1'b0;
        m_ready = 1'b1;

        rst = 1'b1;
        repeat (10) @(posedge clk);
        rst = 1'b0;
        repeat (5) @(posedge clk);

        // ========================================================
        // TEST 1: IMPULSE
        // ========================================================
        $display("");
        $display("==================================================");
        $display("TEST 1: IMPULSE");
        $display("==================================================");

        clear_samples();
        sample_mem[0] = 16'sd16384;

        fork
            send_frame();
            collect_outputs();
        join

        print_some_bins();
        check_impulse();

        repeat (20) @(posedge clk);

        // ========================================================
        // TEST 2: DC
        // ========================================================
        $display("");
        $display("==================================================");
        $display("TEST 2: DC");
        $display("==================================================");

        clear_samples();
        for (i = 0; i < N; i = i + 1)
            sample_mem[i] = 16'sd1024;

        fork
            send_frame();
            collect_outputs();
        join

        print_some_bins();
        check_dc();

        repeat (20) @(posedge clk);

        // ========================================================
        // TEST 3: COSINE AT BIN 5
        // ========================================================
        $display("");
        $display("==================================================");
        $display("TEST 3: COSINE AT BIN 5");
        $display("==================================================");

        clear_samples();
        for (i = 0; i < N; i = i + 1)
            sample_mem[i] = $rtoi(12000.0 * $cos(2.0 * PI * 5.0 * i / N));

        fork
            send_frame();
            collect_outputs();
        join

        print_some_bins();
        check_cosine_bin5();

        repeat (20) @(posedge clk);

        // ========================================================
        // TEST 4: BACKPRESSURE
        // ========================================================
        $display("");
        $display("==================================================");
        $display("TEST 4: BACKPRESSURE");
        $display("==================================================");

        fork
            send_frame();
            collect_outputs_with_backpressure();
        join

        print_some_bins();
        check_cosine_bin5();

        repeat (20) @(posedge clk);

        // ========================================================
        // TEST 5: CONSECUTIVE FRAMES
        // ========================================================
        $display("");
        $display("==================================================");
        $display("TEST 5: CONSECUTIVE FRAMES");
        $display("==================================================");

        check_consecutive_frames();

        // ========================================================
        // Final result
        // ========================================================
        $display("");
        $display("==================================================");
        if (error_count == 0)
            $display("ALL FFT TESTS PASSED.");
        else
            $display("FFT TESTBENCH FAILED with %0d hard error(s).", error_count);
        $display("==================================================");

        $finish;
    end

endmodule