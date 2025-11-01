`default_nettype none
module evt_counter #(parameter MAX_COUNT, parameter COUNT_WIDTH)(
    input wire clk_in,
    input wire rst_in,
    input wire evt_in,
    output logic[COUNT_WIDTH-1:0] count_out
);

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            count_out <= 0; 
        end else begin
            count_out <= (count_out == MAX_COUNT - 1) ? 0 : (evt_in == 1'b1) ? count_out + 1 : count_out;
        end
    end

endmodule
`default_nettype wire