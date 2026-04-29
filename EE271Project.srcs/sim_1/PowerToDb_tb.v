`timescale 1ns/1ps

module PowerToDb_tb;

    reg  [26:0] mag;
    reg         mag_valid;
    wire [6:0]  db;
    wire        valid;
    reg         clk;
    reg         reset;

 
    PowerToDb dut (
        .mag       (mag),
        .mag_valid (mag_valid),
        .db        (db),
        .valid     (valid),
        .clk       (clk),
        .reset     (reset)
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
            mag       = mag_in;
            mag_valid = valid_in;
            @(posedge clk); // cycle 1: casez, msb_valid <= mag_valid
            @(posedge clk); // cycle 2: db <= 3*msb_pos, valid <= msb_valid
            #1;
 
            if (valid_in && db !== expected_db)
                $display("FAIL test %0d: mag=%0d | got db=%0d, expected=%0d",
                         test_num, mag_in, db, expected_db);
            else if (valid_in)
                $display("PASS test %0d: mag=%0d | db=%0d", test_num, mag_in, db);
 
            if (valid !== expected_valid)
                $display("FAIL test %0d: got valid=%0b, expected=%0b",
                         test_num, valid, expected_valid);
            else
                $display("PASS test %0d: valid=%0b", test_num, valid);
        end
    endtask
 
    initial begin
        mag       = 0;
        mag_valid = 0;
        reset     = 1;
        @(posedge clk); @(posedge clk); #1;
        reset = 0;
        @(posedge clk); #1;
 
        
        apply_and_check(27'h4000000, 1, 7'd78, 1, 1); //db = 78
 

        apply_and_check(27'h2000000, 1, 7'd75, 1, 2); //db = 75
 
 
        apply_and_check(27'h0000001, 1, 7'd0, 1, 3); //db = 0
 

        apply_and_check(27'h0001000, 1, 7'd36, 1, 4); //db = 36
 

        apply_and_check(27'h0000000, 1, 7'd0, 1, 5); //db = 0
 
  
        apply_and_check(27'h4000000, 0, 7'd0, 0, 6); //test mag_valid low, should be delayed by 2 cycles 
 

        apply_and_check(27'h1000000, 1, 7'd72, 1, 7); //db = 72
 

        apply_and_check(27'h0008000, 1, 7'd45, 1, 8); //db = 45
 
 
        $display("Done");
        $finish;
    end
 
    initial begin
        $dumpfile("PowerToDb_tb.vcd");
        $dumpvars(0, PowerToDb_tb);
    end

    
endmodule