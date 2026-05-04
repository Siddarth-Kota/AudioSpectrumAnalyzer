module fir#(
    parameter       TAPS = 47,
    parameter       WIDTH = 24
)(
    output wire [WIDTH-1:0] data_out,
    input wire  [WIDTH-1:0] data_in,

    input wire              s_valid,            // Upstream source has data ready for DUT to receive 
    output wire             s_ready,            // DUT can receive data from upstream source 
    output wire             m_valid,             // DUT is ready to send data to downstream block    
    input wire              m_ready,             // Downstream block is ready to accept data

    input wire              clk,
    input wire              reset
);
    reg signed [15:0] coeffs [TAPS-1:0];
    initial begin 
        $readmemh("coeffs.txt", coeffs);
    end

    reg [1:0] curr_state, next_state;
    localparam IDLE = 2'b00;
    localparam FILT = 2'b01;
    localparam STOP = 2'b10;

    reg signed [WIDTH-1:0] shift_in[TAPS-1:0];
    integer i, j;
    always @(posedge clk, posedge reset) begin 
        if(reset) begin 
            for(j = 0; j < TAPS; j = j + 1) begin 
                shift_in[j] <= 0;
            end
        end 
        else if(s_valid && s_ready) begin 
            shift_in[0] <= data_in;
            for(j = 1; j < TAPS; j = j + 1) begin 
                shift_in[j] <= shift_in[j - 1];
            end
        end
    end

    // FIR STATE MACHINE
    reg [5:0] tap_ctr;
    reg signed [39:0] acc;
    reg signed [WIDTH-1:0] final_data_out;
    always @(posedge clk, posedge reset) begin 
        if(reset) begin 
            curr_state <= IDLE;
            tap_ctr <= 0;
            acc <= 0;
        end
        else begin 
            case(curr_state)
                IDLE: begin 
                    if(s_valid && s_ready) begin 
                        curr_state <= FILT;
                        tap_ctr <= 0;
                        acc <= 0;
                    end
                end
                FILT: begin 
                    if(tap_ctr < TAPS) begin 
                        acc <= acc + shift_in[tap_ctr]*coeffs[tap_ctr];
                        tap_ctr <= tap_ctr + 1;
                    end
                    else begin 
                        curr_state <= STOP;
                        final_data_out <= acc[38:15];
                    end
                end
                STOP: begin 
                    if(m_ready) curr_state <= IDLE;
                end
                default: curr_state <= IDLE;
            endcase
        end
    end
    assign data_out = final_data_out;


    assign s_ready = (curr_state == IDLE);
    assign m_valid = (curr_state == STOP);
endmodule
