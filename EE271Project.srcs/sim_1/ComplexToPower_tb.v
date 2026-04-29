`timescale 1ns / 1ps

module ComplexToPower_tb;

    reg  [63:0] fft_tdata;
    reg         fft_tvalid;
    wire [26:0] mag;
    wire        mag_valid;
    reg         clk;
    reg         reset;

 
    ComplexToPower dut (
        .fft_tdata  (fft_tdata),
        .fft_tvalid (fft_tvalid),
        .mag        (mag),
        .mag_valid  (mag_valid),
        .clk        (clk),
        .reset      (reset)
    );

  
    initial clk = 0;
    always #5 clk = ~clk;


    task apply_sample;
        input signed [26:0] re_in;
        input signed [26:0] im_in;
        input [26:0] expected_mag;
        input [63:0] test_num;
        begin
            // Pack re into [26:0], im into [58:32], upper bits 0
            fft_tdata  = {5'b0, im_in, 5'b0, re_in};
            fft_tvalid = 1;
            @(posedge clk); #1; // wait one cycle for output to register
            fft_tvalid = 0;

            if (mag !== expected_mag)
                $display("FAIL test %0d: re=%0d im=%0d | got mag=%0d, expected=%0d",
                         test_num, re_in, im_in, mag, expected_mag);
            else
                $display("PASS test %0d: re=%0d im=%0d | mag=%0d",
                         test_num, re_in, im_in, mag);

            if (mag_valid !== 1)
                $display("FAIL test %0d: mag_valid not asserted", test_num);
        end
    endtask


    initial begin

        fft_tdata  = 0;
        fft_tvalid = 0;
        reset      = 1;

        
        @(posedge clk); @(posedge clk); #1;
        reset = 0;
        @(posedge clk); #1;

        apply_sample(27'd100, 27'd50, 27'd100, 1); //real=100, imag=50 expected max = 100
        apply_sample(27'd30, 27'd200, 27'd200, 2); // real=-300, imag=100  expected max = 300
        apply_sample(-27'd300, 27'd100, 27'd300, 3); // real = -300, imag = 100 expected mag = 300
        apply_sample(-27'd50, -27'd400, 27'd400, 4); // real = -50, imag = -400 expected mag = 400
        apply_sample(27'd0, 27'd0, 27'd0, 5); // both 0 
        apply_sample(27'd256, 27'd256, 27'd256, 6); //real = 256, imag = 256 expected mag = 256
        apply_sample(27'h3FFFFFF, 27'd0, 27'h3FFFFFF, 7); // real = 67108863, imag = 0 expected mag = 67108863

        fft_tdata  = {5'b0, 27'd999, 5'b0, 27'd888}; //fft_tvalid low, should not update mag or mag_valid
        fft_tvalid = 0;
        @(posedge clk); #1;
        if (mag_valid !== 0)
            $display("FAIL test: mag_valid should be 0 when fft_tvalid=0");
        else
            $display("PASS test: mag_valid correctly 0 when fft_tvalid=0");


        fft_tdata  = {5'b0, 27'd500, 5'b0, 27'd500}; //test reseting mid data flow 
        fft_tvalid = 1;
        @(posedge clk); #1;
        reset = 1;
        @(posedge clk); #1;
        if (mag !== 0 || mag_valid !== 0)
            $display("FAIL test: reset did not clear outputs (mag=%0d, mag_valid=%0d)", mag, mag_valid);
        else
            $display("PASS test: reset correctly cleared outputs");
        reset = 0;

        $display("complete");
        $finish;
    end

    initial begin
        $dumpfile("ComplexToPower_tb.vcd");
        $dumpvars(0, ComplexToPower_tb);
    end

endmodule