module fir_tree_accum_4 #(
    parameter TAP_INPUT_WIDTH = 62,
    parameter NUM_TAP_INPUTS = 4,
    parameter OUTPUT_BIT_WIDTH = 65
    
) (
    input wire clk_in,
    input wire rst_in,
    input wire signed [TAP_INPUT_WIDTH - 1:0]  tap_values_in [NUM_TAP_INPUTS - 1:0] ,
    input wire ready,

    output logic tree_accum_busy,
    output logic valid_out,
    output logic signed [OUTPUT_BIT_WIDTH - 1: 0] accum_out
);
    localparam NUM_CYCLES = $clog2(NUM_TAP_INPUTS);
    //number of accumulate terms
    localparam NUM_ACCUM_TERMS_STAGE1 = NUM_TAP_INPUTS >> 1; //2

    //accumulation registers stage A
    logic signed [TAP_INPUT_WIDTH + 1: 0] reg_sum_stage1 [NUM_ACCUM_TERMS_STAGE1 - 1: 0] ;       //2 65-bits


    //accumulation states
    typedef enum{
        STAGE1,
        OUTPUT
    } tree_accum_states;
    
    tree_accum_states state;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            state <= STAGE1;
            // reg_sum_stage1 <= 0;
            for (int i1 = 0; i1 < NUM_ACCUM_TERMS_STAGE1; i1 ++) begin
                reg_sum_stage1[i1] <= 0;
            end

            tree_accum_busy <= 0;
            valid_out <= 0;
            accum_out <= 0;
        end else  begin

            case (state) 
            
            STAGE1: begin
                valid_out <= 0;

                if (ready) begin
                    tree_accum_busy <= 1;
                    
                    for (int i = 0; i < NUM_ACCUM_TERMS_STAGE1; i++) begin //this will take 4 cycles
                        reg_sum_stage1[i] <= $signed(tap_values_in[2*i]) + $signed(tap_values_in[2*i + 1]);
                    end

                    state <= OUTPUT;
                end
            end
            

            OUTPUT: begin
                tree_accum_busy <= 0;
                accum_out <= $signed(reg_sum_stage1[0]) + $signed(reg_sum_stage1[1]); //add two final terms
                valid_out <= 1;
                state <= STAGE1;
            end

            endcase
        end
    end

endmodule