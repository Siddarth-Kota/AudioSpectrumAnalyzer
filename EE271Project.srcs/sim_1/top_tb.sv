`timescale 1ns/1ns
module top_tb;
    logic clk, reset;
    wire m_clk_out; // Capture the output clock from top

    // 100 MHz System Clock (10ns period)
    initial begin 
        clk = 0;
        reset = 1;
        #200;          // Hold reset long enough for Clock Wizard to lock
        reset = 0;
    end
    always #5 clk = ~clk; // #5 gives a 10ns period (100MHz)
    logic m_data;
    top t(
        .CLK(clk),
        .RESET(reset),
        .M_DATA(m_data),
        .M_CLK(m_clk_out), 
        .M_LRSEL(),
        .vgaRed(),
        .vgaGreen(),
        .vgaBlue(),
        .Hsync(),
        .Vsync()
    );

    initial begin
        m_data = 0;
        wait(!reset); // Wait for reset to be DONE
        
        forever begin 
            // Trigger slightly AFTER the edge to avoid simulation races
            @(posedge m_clk_out); 
            #1; // Small delay to ensure clean sampling in simulation
            m_data <= $urandom(); 
        end
    end
    initial begin 
        #1000;
        $finish;
    end
endmodule