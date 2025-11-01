module audio_rate_clk_gen #(
    parameter AUDIO_WORD_WIDTH = 24
)(
    input  logic clk_in,        // 100 MHz input clock
    input  logic rst_in,        // Active low reset
    output logic clk_ws,        // ~2.1168 MHz output clock, 47 sys_clk
    output logic clk_sck,        // ~44.1 kHz output clock, 24 
    output logic new_window,
    output logic last_cycle,
    output logic last_cycle_bit
);


    // Divide factor approximation
    localparam int DIVIDE_FACTOR = 47;
    localparam int BIT_HALF = (DIVIDE_FACTOR/2)-1;
    localparam int BIT_END = DIVIDE_FACTOR-1;

    logic [5:0] ws_counter, sck_counter;

    logic clk_ws_r;  
    logic clk_sck_r;
    assign clk_ws  = clk_ws_r;
    assign clk_sck = clk_sck_r;

    assign last_cycle = (clk_ws_r == 1) && (ws_counter == AUDIO_WORD_WIDTH-1) && (sck_counter == BIT_END);
    assign new_window = (clk_ws_r == 0) && (ws_counter == 0) && (sck_counter == 0);
    assign last_cycle_bit = sck_counter == BIT_END;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            ws_counter  <= 0;
            sck_counter <= 0;
            clk_ws_r    <= 0;
            clk_sck_r   <= 0;

        end else if(sck_counter == BIT_HALF) begin
            sck_counter <= sck_counter + 1;
            clk_sck_r   <= 1;

        end else if (sck_counter == BIT_END) begin
            sck_counter <= 0;
            clk_sck_r   <= 0;

            if (ws_counter == AUDIO_WORD_WIDTH-1) begin
                ws_counter <= 0;
                clk_ws_r   <= ~clk_ws_r;
            end else begin 
                ws_counter <= ws_counter + 1; end

        end else begin 
            sck_counter <= sck_counter + 1; 
        end
    end
endmodule


            