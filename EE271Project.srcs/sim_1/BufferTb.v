`timescale 1ns / 1ps

module tb_buffer_final;

    localparam DEPTH      = 2048;
    localparam ADDR       = 11;
    localparam FRAME_SIZE = 1024;
    localparam FRAME_BITS = 10;

    // Fast simulation-only clocks so this finishes within Vivado's default 1000 ns run.
    // wr_clk period = 0.010 ns
    // rd_clk period = 0.014 ns
    reg wr_clk;
    reg rd_clk;

    reg wr_rst;
    reg rd_rst;

    // Buffer input side, from Window
    reg  [15:0] s_data;
    reg         s_valid;
    wire        s_ready;
    reg         s_last;

    // Buffer output side, to FFT
    wire [31:0] m_data;
    wire        m_valid;
    wire        m_last;
    reg         m_ready;

    integer error_count;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    buffer_final #(
        .DEPTH(DEPTH),
        .ADDR(ADDR),
        .FRAME_SIZE(FRAME_SIZE),
        .FRAME_BITS(FRAME_BITS),
        .GENERATE_LAST(1)
    ) dut (
        .wr_clk  (wr_clk),
        .wr_rst  (wr_rst),

        .s_data  (s_data),
        .s_valid (s_valid),
        .s_ready (s_ready),
        .s_last  (s_last),

        .rd_clk  (rd_clk),
        .rd_rst  (rd_rst),

        .m_data  (m_data),
        .m_valid (m_valid),
        .m_last  (m_last),
        .m_ready (m_ready)
    );

    // ------------------------------------------------------------
    // Clocks
    // ------------------------------------------------------------
    initial begin
        wr_clk = 1'b0;
        forever #0.005 wr_clk = ~wr_clk;
    end

    initial begin
        rd_clk = 1'b0;
        forever #0.007 rd_clk = ~rd_clk;
    end

    // ------------------------------------------------------------
    // Watchdog
    // ------------------------------------------------------------
    initial begin
        #950;
        $display("");
        $display("==================================================");
        $display("ERROR: Buffer testbench watchdog timeout at 950 ns.");
        $display("Something may be stuck.");
        $display("==================================================");
        $finish;
    end

    // ------------------------------------------------------------
    // Reset task
    // ------------------------------------------------------------
    task reset_dut;
        begin
            s_data  = 16'd0;
            s_valid = 1'b0;
            s_last  = 1'b0;
            m_ready = 1'b0;

            wr_rst = 1'b1;
            rd_rst = 1'b1;

            repeat (20) @(posedge wr_clk);
            repeat (20) @(posedge rd_clk);

            wr_rst = 1'b0;
            rd_rst = 1'b0;

            repeat (10) @(posedge wr_clk);
            repeat (10) @(posedge rd_clk);
        end
    endtask

    // ------------------------------------------------------------
    // Write a sequence of samples into buffer input
    // ------------------------------------------------------------
    task write_words;
        input integer count;
        input integer start_value;

        integer i;
        integer wait_count;

        begin : WRITE_WORDS_BODY
            for (i = 0; i < count; i = i + 1) begin
                @(negedge wr_clk);

                s_data  = start_value + i;
                s_valid = 1'b1;
                s_last  = 1'b0;

                wait_count = 0;

                while (s_ready !== 1'b1) begin
                    @(negedge wr_clk);

                    s_data  = start_value + i;
                    s_valid = 1'b1;
                    s_last  = 1'b0;

                    wait_count = wait_count + 1;

                    if (wait_count > 5000) begin
                        $display("ERROR: Timeout waiting for s_ready while writing word %0d.", i);
                        error_count = error_count + 1;
                        s_valid = 1'b0;
                        s_last  = 1'b0;
                        disable WRITE_WORDS_BODY;
                    end
                end

                @(posedge wr_clk);
            end

            @(negedge wr_clk);
            s_data  = 16'd0;
            s_valid = 1'b0;
            s_last  = 1'b0;
        end
    endtask

    // ------------------------------------------------------------
    // Collect and check a sequence of output samples
    // ------------------------------------------------------------
    task collect_words;
        input integer count;
        input integer expected_start;

        integer bin;
        integer wait_count;
        reg [15:0] expected_sample;
        reg        expected_last;

        begin : COLLECT_WORDS_BODY
            bin = 0;
            wait_count = 0;

            m_ready = 1'b1;

            while (bin < count) begin
                @(negedge rd_clk);

                wait_count = wait_count + 1;

                if (wait_count > 10000) begin
                    $display("ERROR: Timeout waiting for output word %0d.", bin);
                    error_count = error_count + 1;
                    disable COLLECT_WORDS_BODY;
                end

                if (m_valid && m_ready) begin
                    expected_sample = expected_start + bin;
                    expected_last   = ((bin % FRAME_SIZE) == (FRAME_SIZE - 1));

                    if (^m_data === 1'bx) begin
                        $display("ERROR: m_data is X at output word %0d.", bin);
                        error_count = error_count + 1;
                    end

                    if (m_data[31:16] !== 16'd0) begin
                        $display("ERROR output word %0d: upper 16 bits are not zero. m_data=%h",
                                 bin, m_data);
                        error_count = error_count + 1;
                    end

                    if (m_data[15:0] !== expected_sample) begin
                        $display("ERROR output word %0d: got sample %h, expected %h",
                                 bin, m_data[15:0], expected_sample);
                        error_count = error_count + 1;
                    end

                    if (m_last !== expected_last) begin
                        $display("ERROR output word %0d: got m_last=%b, expected %b",
                                 bin, m_last, expected_last);
                        error_count = error_count + 1;
                    end

                    bin = bin + 1;
                end
            end

            m_ready = 1'b1;
        end
    endtask

    // ------------------------------------------------------------
    // Collect outputs while applying m_ready backpressure
    // ------------------------------------------------------------
    task collect_words_with_backpressure;
        input integer count;
        input integer expected_start;

        integer bin;
        integer cycle_count;
        integer stall_count;
        integer wait_count;

        reg [31:0] held_data;
        reg        held_last;
        reg        held_valid;
        reg        stalled_prev;

        reg [15:0] expected_sample;
        reg        expected_last;

        begin : BACKPRESSURE_BODY
            bin          = 0;
            cycle_count  = 0;
            stall_count  = 0;
            wait_count   = 0;
            held_data    = 32'd0;
            held_last    = 1'b0;
            held_valid   = 1'b0;
            stalled_prev = 1'b0;

            m_ready = 1'b1;

            while (bin < count) begin
                @(negedge rd_clk);

                wait_count = wait_count + 1;

                if (wait_count > 15000) begin
                    $display("ERROR: Timeout during backpressure test. Collected only %0d words.", bin);
                    error_count = error_count + 1;
                    m_ready = 1'b1;
                    disable BACKPRESSURE_BODY;
                end

                // Check that output stayed stable during previous stall.
                if (stalled_prev) begin
                    if (m_valid !== held_valid) begin
                        $display("ERROR backpressure: m_valid changed while stalled at output word %0d.", bin);
                        error_count = error_count + 1;
                    end

                    if (m_data !== held_data) begin
                        $display("ERROR backpressure: m_data changed while stalled at output word %0d.", bin);
                        error_count = error_count + 1;
                    end

                    if (m_last !== held_last) begin
                        $display("ERROR backpressure: m_last changed while stalled at output word %0d.", bin);
                        error_count = error_count + 1;
                    end
                end

                // Stall every fourth observed output-valid cycle.
                // Use cycle_count, not bin number, to avoid deadlock.
                if (m_valid && ((cycle_count % 4) == 0))
                    m_ready = 1'b0;
                else
                    m_ready = 1'b1;

                if (m_valid && m_ready) begin
                    expected_sample = expected_start + bin;
                    expected_last   = ((bin % FRAME_SIZE) == (FRAME_SIZE - 1));

                    if (m_data[31:16] !== 16'd0) begin
                        $display("ERROR backpressure word %0d: upper 16 bits are not zero. m_data=%h",
                                 bin, m_data);
                        error_count = error_count + 1;
                    end

                    if (m_data[15:0] !== expected_sample) begin
                        $display("ERROR backpressure word %0d: got sample %h, expected %h",
                                 bin, m_data[15:0], expected_sample);
                        error_count = error_count + 1;
                    end

                    if (m_last !== expected_last) begin
                        $display("ERROR backpressure word %0d: got m_last=%b, expected %b",
                                 bin, m_last, expected_last);
                        error_count = error_count + 1;
                    end

                    stalled_prev = 1'b0;
                    bin = bin + 1;
                end else if (m_valid && !m_ready) begin
                    held_data    = m_data;
                    held_last    = m_last;
                    held_valid   = m_valid;
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
    // Test FIFO full behavior.
    //
    // For this specific full test, the read side is held in reset
    // so the FIFO cannot prefetch into its output register. That
    // makes the expected memory depth exactly 2048 writes.
    // ------------------------------------------------------------
    task test_fifo_full;
        integer i;
        integer wait_count;

        begin : FULL_TEST_BODY
            $display("");
            $display("Checking FIFO full behavior...");

            s_data  = 16'd0;
            s_valid = 1'b0;
            s_last  = 1'b0;
            m_ready = 1'b0;

            wr_rst = 1'b1;
            rd_rst = 1'b1;

            repeat (20) @(posedge wr_clk);
            wr_rst = 1'b0;

            repeat (10) @(posedge wr_clk);

            // Write exactly DEPTH words while read side is held reset.
            for (i = 0; i < DEPTH; i = i + 1) begin
                @(negedge wr_clk);

                s_data  = i[15:0];
                s_valid = 1'b1;
                s_last  = 1'b0;

                wait_count = 0;

                while (s_ready !== 1'b1) begin
                    @(negedge wr_clk);
                    wait_count = wait_count + 1;

                    if (wait_count > 5000) begin
                        $display("ERROR: FIFO became full too early at write %0d.", i);
                        error_count = error_count + 1;
                        disable FULL_TEST_BODY;
                    end
                end

                @(posedge wr_clk);
            end

            @(negedge wr_clk);

            // After 2048 writes with no reads, FIFO should be full.
            if (s_ready !== 1'b0) begin
                $display("ERROR: Expected s_ready=0 after filling 2048 words, got s_ready=%b.", s_ready);
                error_count = error_count + 1;
            end else begin
                $display("  FIFO full check passed: s_ready deasserted after 2048 writes.");
            end

            s_valid = 1'b0;
            s_last  = 1'b0;

            // Cleanup so future tests would not inherit rd_rst asserted.
            rd_rst = 1'b0;
            repeat (10) @(posedge rd_clk);
        end
    endtask

    // ------------------------------------------------------------
    // Main simulation
    // ------------------------------------------------------------
    initial begin
        error_count = 0;

        $display("");
        $display("==================================================");
        $display("BUFFER_FINAL TESTBENCH START");
        $display("==================================================");

        // ========================================================
        // TEST 1: Basic 1024-word frame
        // ========================================================
        $display("");
        $display("==================================================");
        $display("TEST 1: BASIC 1024-WORD FRAME");
        $display("==================================================");

        reset_dut();

        fork
            write_words(1024, 16'h0000);
            collect_words(1024, 16'h0000);
        join

        $display("  Basic frame test complete.");

        // ========================================================
        // TEST 2: Output backpressure
        // ========================================================
        $display("");
        $display("==================================================");
        $display("TEST 2: OUTPUT BACKPRESSURE");
        $display("==================================================");

        reset_dut();

        fork
            write_words(1024, 16'h1000);
            collect_words_with_backpressure(1024, 16'h1000);
        join

        $display("  Backpressure test complete.");

        // ========================================================
        // TEST 2B: Two consecutive 1024-sample frames
        // Verifies generated m_last at output word 1023 and 2047.
        // ========================================================
        $display("");
        $display("==================================================");
        $display("TEST 2B: TWO CONSECUTIVE FRAMES / M_LAST RESET");
        $display("==================================================");

        reset_dut();

        fork
            write_words(2048, 16'h2000);
            collect_words(2048, 16'h2000);
        join

        $display("  Two-frame m_last test complete.");

        // ========================================================
        // TEST 3: FIFO full behavior
        // ========================================================
        $display("");
        $display("==================================================");
        $display("TEST 3: FIFO FULL / S_READY BACKPRESSURE");
        $display("==================================================");

        test_fifo_full();

        // ========================================================
        // Final result
        // ========================================================
        $display("");
        $display("==================================================");
        if (error_count == 0)
            $display("ALL BUFFER TESTS PASSED.");
        else
            $display("BUFFER TESTBENCH FAILED with %0d error(s).", error_count);
        $display("==================================================");

        $finish;
    end

endmodule