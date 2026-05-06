`timescale 1ns / 1ps

module tb_buffer_final;

    parameter N = 1024;
    parameter WIDTH = 16;
    parameter CLK_PERIOD = 10;

    reg clk;
    reg rst_n;

    reg signed [WIDTH-1:0] s_data;
    reg s_valid;
    wire s_ready;

    wire signed [WIDTH-1:0] m_data;
    wire m_valid;
    reg m_ready;

    integer error_count;
    integer pass_count;

    buffer_final #(
        .N(N),
        .WIDTH(WIDTH)
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

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    task do_reset;
        begin
            @(negedge clk);
            rst_n   = 0;
            s_valid = 0;
            s_data  = 0;
            m_ready = 0;

            repeat (5) @(posedge clk);

            @(negedge clk);
            rst_n = 1;

            repeat (2) @(posedge clk);
        end
    endtask

    task send_frame;
        input integer start_val;
        input integer gap_enable;
        integer i;
        begin
            i = 0;

            while (i < N) begin
                @(negedge clk);

                s_data  = start_val + i;
                s_valid = 1;

                @(posedge clk);
                #1;

                if (s_ready) begin
                    i = i + 1;

                    if (gap_enable && ((i % 8) == 0)) begin
                        @(negedge clk);
                        s_valid = 0;
                        repeat (4) @(posedge clk);
                    end
                end
            end

            @(negedge clk);
            s_valid = 0;
        end
    endtask

    task receive_and_check_frame;
        input integer frame_num;
        input integer expected_start;
        input integer stall_enable;

        integer i;
        reg signed [WIDTH-1:0] expected;
        begin
            i = 0;
            m_ready = 0;

            while (!m_valid)
                @(posedge clk);

            while (i < N) begin
                @(negedge clk);

                if (stall_enable && ((i % 3) == 0))
                    m_ready = 0;
                else
                    m_ready = 1;

                @(posedge clk);
                #1;

                if (m_valid && m_ready) begin
                    expected = expected_start + i;

                    if (m_data !== expected) begin
                        $display("[ERROR] Frame %0d sample %0d: expected %0d, got %0d",
                                 frame_num, i, expected, m_data);
                        error_count = error_count + 1;
                    end

                    i = i + 1;
                end
            end

            @(negedge clk);
            m_ready = 0;

            if (error_count == 0)
                $display("[PASS] Frame %0d correct", frame_num);
            else
                $display("[DONE] Frame %0d checked", frame_num);

            pass_count = pass_count + 1;
        end
    endtask

    initial begin
        error_count = 0;
        pass_count  = 0;

        clk     = 0;
        rst_n   = 0;
        s_data  = 0;
        s_valid = 0;
        m_ready = 0;

        $display("========================================");
        $display(" buffer_final Testbench Start");
        $display("========================================");

        // TEST 1: Basic one frame
        $display("\n--- TEST 1: Basic single frame ---");
        do_reset();

        fork
            send_frame(100, 0);
            receive_and_check_frame(1, 100, 0);
        join

        // TEST 2: Two back-to-back frames
        $display("\n--- TEST 2: Back-to-back frames ---");
        do_reset();

        fork
            begin
                send_frame(0, 0);
                send_frame(1000, 0);
            end

            begin
                receive_and_check_frame(2, 0, 0);
                receive_and_check_frame(3, 1000, 0);
            end
        join

        // TEST 3: Output backpressure
        $display("\n--- TEST 3: m_ready stalls ---");
        do_reset();

        fork
            send_frame(500, 0);
            receive_and_check_frame(4, 500, 1);
        join

        // TEST 4: Input gaps
        $display("\n--- TEST 4: s_valid gaps ---");
        do_reset();

        fork
            send_frame(200, 1);
            receive_and_check_frame(5, 200, 0);
        join

        // TEST 5: Both buffers full, s_ready should drop
        $display("\n--- TEST 5: both buffers full ---");
        do_reset();

        m_ready = 0;

        send_frame(0, 0);
        send_frame(1000, 0);

        repeat (5) @(posedge clk);
        #1;

        if (s_ready == 0) begin
            $display("[PASS] s_ready deasserted when both buffers full");
            pass_count = pass_count + 1;
        end else begin
            $display("[ERROR] s_ready stayed high when both buffers should be full");
            error_count = error_count + 1;
        end

        // Drain two frames
        fork
            begin
                receive_and_check_frame(6, 0, 0);
                receive_and_check_frame(7, 1000, 0);
            end
        join

        repeat (5) @(posedge clk);
        #1;

        if (s_ready == 1) begin
            $display("[PASS] s_ready reasserted after draining");
            pass_count = pass_count + 1;
        end else begin
            $display("[ERROR] s_ready did not reassert after draining");
            error_count = error_count + 1;
        end

        // TEST 6: Reset mid-write
        $display("\n--- TEST 6: reset mid-write ---");
        do_reset();

        begin : partial_write
            integer i;
            for (i = 0; i < N/2; i = i + 1) begin
                @(negedge clk);
                s_data  = 999;
                s_valid = 1;
                @(posedge clk);
            end
            @(negedge clk);
            s_valid = 0;
        end

        do_reset();

        fork
            send_frame(42, 0);
            receive_and_check_frame(8, 42, 0);
        join

        $display("\n========================================");
        $display(" Testbench complete");
        $display(" Passed checks : %0d", pass_count);
        $display(" Errors        : %0d", error_count);
        $display("========================================");

        if (error_count == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** TESTS FAILED ***");

        $finish;
    end

    initial begin
        #(CLK_PERIOD * 2000000);
        $display("[WATCHDOG] Simulation timeout");
        $finish;
    end

endmodule