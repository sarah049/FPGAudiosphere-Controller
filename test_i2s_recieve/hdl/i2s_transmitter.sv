module i2s_transmitter #(
    parameter AUDIO_WORD_WIDTH=24
) (
    input wire clk_in,              // system clk @ 100MHz
    input wire rst_in,
    input wire [AUDIO_WORD_WIDTH-1:0] data_left,
    input wire [AUDIO_WORD_WIDTH-1:0] data_right,
    input wire data_valid,
    input wire on_last_cycle,  
    input wire on_last_cycle_bit,    
    input logic ws,  
    input logic sclk,
    output logic sd                 //serial data to receiver
);

    logic [AUDIO_WORD_WIDTH-1:0] data_left_sd;
    logic [AUDIO_WORD_WIDTH-1:0] data_right_sd;
    assign sd = (!ws) ? data_left_sd[AUDIO_WORD_WIDTH-1] : data_right_sd[AUDIO_WORD_WIDTH-1];

    always @(posedge clk_in) begin
        if(rst_in) begin
            data_left_sd  <= 0; 
            data_right_sd <= 0; 

        end else if (on_last_cycle)begin
            data_left_sd  <= (data_valid) ? data_left  : 0;  
            data_right_sd <= (data_valid) ? data_right : 0; 

        end else if (on_last_cycle_bit) begin
            if (!ws) begin data_left_sd  <=  {data_left_sd[AUDIO_WORD_WIDTH-2:0], 1'b0};  end 
            else     begin data_right_sd <=  {data_right_sd[AUDIO_WORD_WIDTH-2:0], 1'b0}; end 
        end
    end
endmodule