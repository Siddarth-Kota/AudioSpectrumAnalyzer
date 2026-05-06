`timescale 1ns / 1ps

module ComplexToPower_tb;

    reg  [63:0] s_axis_tdata;
    reg         s_axis_tvalid;
    wire        s_axis_tready;

    wire [26:0] m_axis_tdata;
    wire        m_axis_tvalid;
    reg         m_axis_tready;

    reg         clk;
    reg         reset;

    ComplexToPower dut (
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

    task apply_sample;
        input signed [26:0] re_in;
        input signed [26:0] im_in;
        input [26:0] expected_mag;
        input [63:0] test_num;
        begin
            // put re into [26:0], im into [58:32], upper bits 0
            s_axis_tdata  = {5'b0, im_in, 5'b0, re_in};
            s_axis_tvalid = 1;
            @(posedge clk); #1; // give one cycle for output to register
            s_axis_tvalid = 0;

            if (m_axis_tdata !== expected_mag)
                $display("FAIL test %0d: re=%0d im=%0d | got mag=%0d, expected=%0d",
                         test_num, re_in, im_in, m_axis_tdata, expected_mag);
            else
                $display("PASS test %0d: re=%0d im=%0d | mag=%0d",
                         test_num, re_in, im_in, m_axis_tdata);

            if (m_axis_tvalid !== 1)
                $display("FAIL test %0d: m_axis_tvalid not asserted", test_num);
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

        apply_sample(27'd100,      27'd50,       27'd100,      1); // re>im, expect 100
        apply_sample(27'd30,       27'd200,       27'd200,      2); // im>re, expect 200
        apply_sample(-27'd300,     27'd100,       27'd300,      3); // neg re, expect 300
        apply_sample(-27'd50,      -27'd400,      27'd400,      4); // neg im, expect 400
        apply_sample(27'd0,        27'd0,         27'd0,        5); // both 0
        apply_sample(27'd256,      27'd256,       27'd256,      6); // equal, expect 256
        apply_sample(27'h3FFFFFF,  27'd0,         27'h3FFFFFF,  7); // max re, expect max

        // tvalid low — output should deassert after one cycle
        s_axis_tdata  = {5'b0, 27'd999, 5'b0, 27'd888};
        s_axis_tvalid = 0;
        @(posedge clk); #1;
        if (m_axis_tvalid !== 0)
            $display("FAIL test Tvalidlow: m_axis_tvalid should be 0 when s_axis_tvalid=0");
        else
            $display("PASS test Tvalidlow: m_axis_tvalid correctly 0 when s_axis_tvalid=0");

        // backpressure test — hold m_axis_tready low, check tready deasserts
        s_axis_tdata  = {5'b0, 27'd123, 5'b0, 27'd456};
        s_axis_tvalid = 1;
        m_axis_tready = 0;
        @(posedge clk); #1;
        // Testing Tready under backpressure — s_axis_tready should be 0 when m_axis_tready=0 and output valid
        @(posedge clk); #1;
        if (s_axis_tready !== 0)
            $display("FAIL test Backpressure: s_axis_tready should be 0 when m_axis_tready=0 and output valid");
        else
            $display("PASS test Backpressure: s_axis_tready correctly 0 under backpressure");
        m_axis_tready = 1;
        s_axis_tvalid = 0;
        @(posedge clk); #1;

        // Testing a reset middle of data transfer 
        s_axis_tdata  = {5'b0, 27'd500, 5'b0, 27'd500};
        s_axis_tvalid = 1;
        @(posedge clk); #1;
        reset = 1;
        @(posedge clk); #1;
        if (m_axis_tdata !== 0 || m_axis_tvalid !== 0)
            $display("FAIL test ResetMidStream: reset did not clear outputs (mag=%0d, tvalid=%0d)",
                     m_axis_tdata, m_axis_tvalid);
        else
            $display("PASS test ResetMidStream: reset correctly cleared outputs");
        reset = 0;

        $display("Complete Yippie!");
        $finish;
    end

    initial begin
        $dumpfile("ComplexToPower_tb.vcd");
        $dumpvars(0, ComplexToPower_tb);
    end

endmodule
