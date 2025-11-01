module fir_tree_accum #(
    parameter TAP_INPUT_WIDTH = 56,
    parameter NUM_CYCLES = 4,
    parameter NUM_TAP_INPUTS = 16,
    parameter OUTPUT_BIT_WIDTH = 60
    
) (
    input wire clk_in,
    input wire rst_in,
    input wire signed [NUM_TAP_INPUTS - 1:0] [TAP_INPUT_WIDTH - 1:0] tap_values_in,
    input wire last_tree,
    output wire tree_accum_busy,
    output wire valid_out,
    output wire signed [OUTPUT_BIT_WIDTH - 1: 0] accum_out
);
    
    //number of accumulate terms
    localparam NUM_ACCUM_TERMS_STAGE1 = NUM_TAP_INPUTS >> 1; //8
    localparam NUM_ACCUM_TERMS_STAGE2 = NUM_TAP_INPUTS >> 2; //4
    localparam NUM_ACCUM_TERMS_STAGE3 = NUM_TAP_INPUTS >> 3; //2

    //accumulation registers stage A
    logic signed [NUM_ACCUM_TERMS_STAGE1 - 1: 0] [TAP_INPUT_WIDTH: 0] reg_sum_stage1;       //8 57-bits
    logic signed [NUM_ACCUM_TERMS_STAGE2 - 1: 0] [TAP_INPUT_WIDTH + 1: 0] reg_sum_stage2;   //4 58-bits
    logic signed [NUM_ACCUM_TERMS_STAGE3 - 1: 0] [TAP_INPUT_WIDTH + 2: 0] reg_sum_stage3;   //2 59-bits


    //accumulation states
    typedef enum{
        STAGE1,
        STAGE2,
        STAGE3, 
        OUTPUT
    } tree_accum_states;
    
    tree_accum_states state;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            state <= STAGE1;
            reg_sum_stage1 <= 0;
            reg_sum_stage2 <= 0;
            reg_sum_stage3 <= 0;

            tree_accum_busy <= 0;
            accum_out <= 0;
            valid_out <= 0;
        end else begin

            case (state) 
            
            STAGE1: begin
                tree_accum_busy <= 1;
                valid_out <= 0;
                for (int i = 0; i < NUM_ACCUM_TERMS_STAGE1; i++) begin
                    if (last_stage && i >= 4) reg_sum_stage1[i] <= 0; //when we get to 13th tree, 8 leaves should be 0
                    else reg_sum_stage1[i] <= tap_values_in[2*i] + tap_values_in[2*i + 1];
                end
                state <= STATE2;
            end

            STAGE2: begin
                for (int i = 0; i < NUM_ACCUM_TERMS_STAGE2; i++) begin
                    reg_sum_stage2[i] <= reg_sum_stage1[2*i] + reg_sum_stage1[2*i + 1];
                end
                state <= STATE3;
            end
            
            STAGE3: begin
                for (int i = 0; i < NUM_ACCUM_TERMS_STAGE3; i++) begin
                    reg_sum_stage3[i] <= reg_sum_stage2[2*i] + reg_sum_stage2[2*i + 1];
                end
                state <= OUTPUT;
            end

            OUTPUT: begin
                tree_accum_busy <= 0;
                accum_out <= reg_sum_stage3[0] + reg_sum_stage3[1];
                valid_out <= 1;
                state <= STAGE1;
            end

            endcase
        end
    end

endmodule