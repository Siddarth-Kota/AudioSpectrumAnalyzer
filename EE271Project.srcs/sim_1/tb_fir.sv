module tb_fir;
    logic reset, clk;
    initial begin 
        clk = 0;
        reset = 1;
        @(posedge clk); 
        reset = 0;
    end
    always #10 clk = ~clk;

    logic signed [23:0] data_in, data_out;
    logic s_valid, s_ready, m_valid, m_ready;
    fir f(
        .data_out(data_out),
        .data_in(data_in),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .clk(clk),
        .reset(reset)
    );

    initial begin 
        s_valid <= 0;
        data_in <= 0;
        m_ready <= 1; // Keep ready high to cycle back to IDLE quickly
        @(posedge clk);
        
        // Send a pulse of '1', then keep s_valid high with '0's
        // so the state machine keeps triggering.
        for(int i = 0; i < 500; i++) begin 
            if (i == 0) data_in <= 1; 
            else data_in <= 0;
            
            s_valid <= 1; 
            @(posedge clk);
            
            // Wait until the FIR is done with this sample before sending next
            wait(s_ready); 
        end
    end
    //initial begin 
        //s_valid <= 0;
        //data_in <= 0;
        //m_ready <= 0;
        //@(posedge clk);
        //s_valid <= 1;
        //data_in <= 1;
        //@(posedge clk);
        //for(int i = 0; i < 500; i++) begin 
            //s_valid <= 1;
            //data_in <= 0;
            //if(m_valid) m_ready <= 1;
            //else m_ready <= 0;
            //$display("data out: %d", data_out);
            //@(posedge clk);
        //end
    //end
endmodule