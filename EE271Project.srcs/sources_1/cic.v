module cic #(parameter N = 4,   // not used, but for completion, number of stages of integrator
        parameter M = 1,        // not really used, but for completion
        parameter R = 64,
        parameter WIDTH=24,
        parameter DEC_REC_WIDTH= 6)(            // width of decimation counter determined from log2(R)
            output wire [WIDTH-1:0] data_out,
            //input wire s_valid,            // Upstream source has data ready for DUT to receive 
            //output wire s_ready,            // DUT can receive data from upstream source 
            output wire m_valid,             // DUT is ready to send data to downstream block    
            input wire m_ready,             // Downstream block is ready to accept data
            input wire data_in,

            input wire clk,
            input wire reset
);
    reg in;
    always @(posedge clk, posedge reset) begin 
        if(reset) in <= 0;
        else in <= data_in;
    end
    wire [1:0] xi = in ? 2'sd1 : -2'sd1; 

    // integrator
    reg signed [WIDTH:0] integrator0, integrator1, integrator2, integrator3;
    always @(posedge clk, posedge reset) begin 
        if(reset) begin 
            integrator0 <= 0;
            integrator1 <= 0;
            integrator2 <= 0;
            integrator3 <= 0;
        end
        else begin 
            integrator0 <= integrator0 + xi;
            integrator1 <= integrator1 + integrator0;
            integrator2 <= integrator2 + integrator1;
            integrator3 <= integrator3 + integrator2;
        end
    end

    // down-sampling counter
    reg [DEC_REC_WIDTH-1:0] dec_counter;
    wire sample_en;
    assign sample_en = dec_counter == R - 1; 
    always @(posedge clk, posedge reset) begin 
        if(reset || sample_en) begin 
            dec_counter <= 0;
        end
        else begin 
            dec_counter <= dec_counter + 1;
        end
    end

    // comb
    reg signed [WIDTH-1:0] raw_pcm;
    reg signed [WIDTH:0] integrator3_d;
    reg signed [WIDTH:0] comb0, comb0_d, comb1, comb1_d, comb2, comb2_d, comb3;
    reg data_valid;
    always @(posedge clk, posedge reset) begin 
        if(reset) begin 
            integrator3_d <= 0;

            comb0 <= 0;
            comb0_d <= 0;

            comb1 <= 0;
            comb1_d <= 0;

            comb2 <= 0;
            comb2_d <= 0;

            comb3 <= 0;

            raw_pcm <= 0;
            data_valid <= 0;
        end
        else if(sample_en && (comb3 != 0)) begin // wait for valid data
            comb0 <= integrator3 - integrator3_d;
            integrator3_d <= integrator3;

            comb1 <= comb0 - comb0_d;
            comb0_d <= comb0;

            comb2 <= comb1 - comb1_d;
            comb1_d <= comb1;

            comb3 <= comb2 - comb2_d;
            comb2_d <= comb2;

            raw_pcm <= comb3[WIDTH-1:0];
            data_valid <= 1;
        end
        else if(sample_en) begin 
            comb0 <= integrator3 - integrator3_d;
            integrator3_d <= integrator3;

            comb1 <= comb0 - comb0_d;
            comb0_d <= comb0;

            comb2 <= comb1 - comb1_d;
            comb1_d <= comb1;

            comb3 <= comb2 - comb2_d;
            comb2_d <= comb2;
        end
        else begin 
            data_valid <= 0;
        end
    end

    reg last_valid;
    always @(posedge clk, posedge reset) begin 
        if(reset) begin 
            last_valid <= 0;
        end 
        else if(data_valid)begin 
            last_valid <= 1;
        end
        else if(m_valid && m_ready) begin 
            last_valid <= 0;
        end
    end

    assign m_valid = last_valid;

    reg [WIDTH-1:0] last_pcm;
    always @(posedge clk, posedge reset) begin 
        if(reset) last_pcm <= 0;
        else if (m_valid && m_ready) last_pcm <= raw_pcm;
    end

    assign data_out = last_pcm;

endmodule