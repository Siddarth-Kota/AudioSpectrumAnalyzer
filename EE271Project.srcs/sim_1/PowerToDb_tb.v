`timescale 1ns/1ps

module PowerToDb_tb;

    reg  [26:0] s_axis_tdata;
    reg         s_axis_tvalid;
    wire        s_axis_tready;

    wire [6:0]  m_axis_tdata;
    wire        m_axis_tvalid;
    reg         m_axis_tready;

    reg         clk;
    reg         reset;

    PowerToDb dut (
        .s_axis_tdata  (s_axis_tdata),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tready (s_axis_tready),
        .m_axis_tdata  (m_axis_tdata),
        .m_axis_tvalid (m_axis_tvalid),
        .m_axis_tready (m_axis_tready),
        .clk           (clk),
        .reset         (reset)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task apply_and_check;
        input [26:0]  mag_in;
        input         valid_in;
        input [6:0]   expected_db;
        input         expected_valid;
        input integer test_num;
        begin
            s_axis_tdata  = mag_in;
            s_axis_tvalid = valid_in;
            @(posedge clk); #1;  

            if (valid_in && m_axis_tdata !== expected_db)
                $display("FAIL test %0d: mag=0x%07h | got db=%0d, expected=%0d",
                         test_num, mag_in, m_axis_tdata, expected_db);
            else if (valid_in)
                $display("PASS test %0d: mag=0x%07h | db=%0d", test_num, mag_in, m_axis_tdata);

            if (m_axis_tvalid !== expected_valid)
                $display("FAIL test %0d: got m_axis_tvalid=%0b, expected=%0b",
                         test_num, m_axis_tvalid, expected_valid);
            else
                $display("PASS test %0d: m_axis_tvalid=%0b", test_num, m_axis_tvalid);
        end
    endtask

    initial begin
        s_axis_tdata  = 0;
        s_axis_tvalid = 0;
        m_axis_tready = 1;  // downstream always ready
        reset         = 1;

        @(posedge clk); @(posedge clk); #1;
        reset = 0;
        @(posedge clk); #1;

        apply_and_check(27'h4000000, 1, 7'd78, 1, 1); // MSB=26, db=78
        apply_and_check(27'h2000000, 1, 7'd75, 1, 2); // MSB=25, db=75
        apply_and_check(27'h0000001, 1, 7'd0,  1, 3); // MSB=0,  db=0
        apply_and_check(27'h0001000, 1, 7'd36, 1, 4); // MSB=12, db=36
        apply_and_check(27'h0000000, 1, 7'd0,  1, 5); // all zeros, db=0
        apply_and_check(27'h4000000, 0, 7'd0,  0, 6); // tvalid low — m_axis_tvalid should go low
        apply_and_check(27'h1000000, 1, 7'd72, 1, 7); // MSB=24, db=72
        apply_and_check(27'h0008000, 1, 7'd45, 1, 8); // MSB=15, db=45

        // backpressure test — hold m_axis_tready low
        s_axis_tdata  = 27'h2000000;
        s_axis_tvalid = 1;
        m_axis_tready = 0;
        @(posedge clk); #1; // fills output register, tready should deassert
        @(posedge clk); #1;
        if (s_axis_tready !== 0)
            $display("FAIL test backpressure: s_axis_tready should be 0 when m_axis_tready=0 and output valid");
        else
            $display("PASS test backpressure: s_axis_tready correctly 0 under backpressure");
        m_axis_tready = 1;
        s_axis_tvalid = 0;
        @(posedge clk); #1;

        // reset test
        s_axis_tdata  = 27'h1000000;
        s_axis_tvalid = 1;
        @(posedge clk); #1;
        reset = 1;
        @(posedge clk); #1;
        if (m_axis_tdata !== 0 || m_axis_tvalid !== 0)
            $display("FAIL test reset: reset did not clear outputs (db=%0d, tvalid=%0d)",
                     m_axis_tdata, m_axis_tvalid);
        else
            $display("PASS test reset: reset correctly cleared outputs");
        reset = 0;

        $display("Done :)");
        $finish;
    end

    initial begin
        $dumpfile("PowerToDb_tb.vcd");
        $dumpvars(0, PowerToDb_tb);
    end

endmodule