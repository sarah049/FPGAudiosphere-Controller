module fir_tree_accum_8 #(
    parameter TAP_INPUT_WIDTH = 59,
    parameter NUM_TAP_INPUTS = 8,
    parameter OUTPUT_BIT_WIDTH = 62
    
) (
    input wire clk_in,
    input wire rst_in,
    input wire signed [TAP_INPUT_WIDTH - 1:0] tap_values_in [NUM_TAP_INPUTS - 1:0] ,
    input wire ready,

    // output logic signed [TAP_INPUT_WIDTH + 1: 0] reg_sum_stage1 [4 - 1: 0] ,
    // output logic signed [TAP_INPUT_WIDTH + 2: 0] reg_sum_stage2 [2 - 1: 0] ,

    output logic tree_accum_busy,
    output logic valid_out,
    output logic signed [OUTPUT_BIT_WIDTH - 1: 0] accum_out
);
    localparam NUM_CYCLES = $clog2(NUM_TAP_INPUTS);
    //number of accumulate terms
    localparam NUM_ACCUM_TERMS_STAGE1 = NUM_TAP_INPUTS >> 1; //4
    localparam NUM_ACCUM_TERMS_STAGE2 = NUM_TAP_INPUTS >> 2; //2

    //accumulation registers stage A
    logic signed [TAP_INPUT_WIDTH + 1: 0] reg_sum_stage1 [NUM_ACCUM_TERMS_STAGE1 - 1: 0] ;       //4 58-bits
    logic signed [TAP_INPUT_WIDTH + 2: 0] reg_sum_stage2 [NUM_ACCUM_TERMS_STAGE2 - 1: 0] ;       //2 59-bits

    
    //accumulation states
    typedef enum{
        STAGE1,
        STAGE2,
        OUTPUT
    } tree_accum_states;
    
    tree_accum_states state;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            state <= STAGE1;
            for (int i1 = 0; i1 < NUM_ACCUM_TERMS_STAGE1; i1 ++) begin
                reg_sum_stage1[i1] <= 0;
            end

            for (int i2 = 0; i2 < NUM_ACCUM_TERMS_STAGE2; i2 ++) begin
                reg_sum_stage2[i2] <= 0;
            end
            // reg_sum_stage1 <= 0;
            // reg_sum_stage2 <= 0;

            tree_accum_busy <= 0;
            valid_out <= 0;
            accum_out <= 0;
        end else begin

            case (state) 
            
            STAGE1:  begin
                valid_out <= 0;

                if (ready) begin
                    tree_accum_busy <= 1;

                    for (int i = 0; i < NUM_ACCUM_TERMS_STAGE1; i++) begin
                        reg_sum_stage1[i] <= $signed(tap_values_in[2*i]) + $signed(tap_values_in[2*i + 1]);
                    end

                    state <= STAGE2;
                end
            end

            STAGE2: begin
              
                for (int j = 0; j < NUM_ACCUM_TERMS_STAGE2; j++) begin
                    reg_sum_stage2[j] <= $signed(reg_sum_stage1[2*j]) + $signed(reg_sum_stage1[2*j + 1]);
                end

                state <= OUTPUT;


            end
            

            OUTPUT: begin
                tree_accum_busy <= 0;
                accum_out <= $signed(reg_sum_stage2[0]) + $signed(reg_sum_stage2[1]);
                valid_out <= 1;
                state <= STAGE1;
            end

            endcase
        end
    end

endmodule