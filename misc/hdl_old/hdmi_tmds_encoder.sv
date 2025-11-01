`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)
 
module tmds_encoder(
    input wire clk_in,
    input wire rst_in,
    input wire [7:0] data_in,  // video data (red, green or blue)
    input wire [1:0] control_in, //for blue set to {vs,hs}, else will be 0
    input wire ve_in,  // video data enable, to choose between control or video signal
    output logic [9:0] tmds_out
);
 
    logic [8:0] q_m;
    tm_choice mtm(
        .data_in(data_in),
        .qm_out(q_m));
    
    // Internal Registers
    logic [4:0] tally;
    logic [9:0] out_val; 

    assign tmds_out = out_val;


    // Internal Logic
    logic [4:0] delta;

    logic [9:0] q_out;
    logic[3:0] dataN1;
    logic[3:0] dataN0;


    always_comb begin

        if(rst_in) begin // If recieving rst signal, immediately output 0
            q_out = 0;
            delta = 0;

        end else if (!ve_in) begin // If recieving ve_in signal, immediately output control

            case (control_in)
                2'b00: q_out = 10'b11_0101_0100;  // x354
                2'b01: q_out = 10'b00_1010_1011; // x0AB
                2'b10: q_out = 10'b01_0101_0100; // x154
                2'b11: q_out = 10'b10_1010_1011; // x2AB
            endcase

            delta = 0;

        end else begin // 

            dataN1 = q_m[7] + q_m[6] + q_m[5] + q_m[4] + q_m[3] + q_m[2] + q_m[1] + q_m[0];
            dataN0 = !q_m[7] + !q_m[6] + !q_m[5] + !q_m[4] + !q_m[3] + !q_m[2] + !q_m[1] + !q_m[0];
            
            if (tally == 0 || dataN1 == dataN0) begin // CONTROL FLOW 1 TRUE
            
                q_out[9] = !q_m[8];
                q_out[8] = q_m[8];
                q_out[7:0] = (q_m[8]) ? q_m[7:0] : ~q_m[7:0];

                if (q_m[8] == 0) begin // CONTROL FLOW 2 TRUE
                    delta = dataN0 - dataN1;

                end else begin // CONTROL FLOW 2 FALSE
                    delta = dataN1 - dataN0;

                end

            end else begin // CONTROL FLOW 1 FALSE

                if ((tally[4] == 0 && dataN1 > dataN0) || (tally[4] == 1 && dataN1 < dataN0)) begin // CONTROL FLOW 2 TRUE
                    q_out[9] = 1;
                    q_out[8] = q_m[8];
                    q_out[7:0] = ~q_m[7:0];  
                    delta = dataN0 - dataN1 + {q_m[8], 1'b0};

                end else begin // CONTROL FLOW 2 True
                    q_out[9] = 0;
                    q_out[8] = q_m[8];
                    q_out[7:0] = q_m[7:0];  
                    delta = dataN1 - dataN0 - ((!q_m[8]) << 1);
                end

            end

        end
    
    end

    always_ff @(posedge clk_in) begin

        if(rst_in || !ve_in) begin
            tally <= 0;
            out_val <= q_out;
        end else begin
            tally <= tally + delta;
            out_val <= q_out;
        end

    end 
 
endmodule
 
`default_nettype wire
