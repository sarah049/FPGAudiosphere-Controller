module fir_filter #(
    parameter HRIR_COEFF_BIT_WIDTH = 32,
    parameter AUDIO_WORD_WIDTH = 24,
    parameter NUM_AZIMUTHS = 25,
    parameter NUM_LOAD_MULT_TERMS = 8,
    parameter FIR_OUTPUT_BIT_WIDTH = 66,
    parameter NUM_TOTAL_TERMS = 200
) ( 
    input wire clk_in,
    input wire rst_in,
    input wire start, // falling edge of SCK 
    input wire signed [AUDIO_WORD_WIDTH - 1: 0] audio_sample_in,
    input wire signed [HRIR_COEFF_BIT_WIDTH - 1: 0] coeff_in,
    input wire ws_in, // left (0) or right (1) channel
    input wire signed [$clog2(NUM_AZIMUTHS): 0] azimuth_in,
    //should have a valid in signal?

    output logic load_ready, //initiate read from HRIR BRAM
    output logic fir_busy, //if low, in mult_stage
    output logic ws_out, //FILL in logic for this!
    output logic fir_valid_out,
    output logic signed [AUDIO_WORD_WIDTH - 1: 0] audio_sample_out, //200 = [NUM_TOTAL_TERMS - 1: 0]  x 24
    output logic signed [FIR_OUTPUT_BIT_WIDTH - 1: 0] fir_out
);

typedef enum { 
    INITIAL,
    LOAD,
    MULTIPLY,
    TREE_ACCUMA,
    TREE_ACCUMB,
    TREE_ACCUMC
} fir_states;

fir_states fir_state;

localparam MULT_BIT_WIDTH = HRIR_COEFF_BIT_WIDTH + AUDIO_WORD_WIDTH; //32 + 24 = 56
localparam NUM_MULT_CYCLES = NUM_TOTAL_TERMS/NUM_LOAD_MULT_TERMS; //25

logic load_wait;
logic [$clog2(NUM_LOAD_MULT_TERMS) - 1: 0] load_count;
logic [$clog2(NUM_TOTAL_TERMS) - 1: 0] total_terms_count; //200, max 256
logic [$clog2(NUM_MULT_CYCLES) - 1: 0] cycle_offset;
logic ws_buffer;

logic [$clog2(NUM_LOAD_MULT_TERMS -1) - 1: 0] load_mult_ix, mult_ix;

logic signed [NUM_LOAD_MULT_TERMS - 1: 0] [AUDIO_WORD_WIDTH - 1: 0] audio_word_registers;
logic signed [NUM_LOAD_MULT_TERMS - 1: 0] [HRIR_COEFF_BIT_WIDTH - 1: 0] hrir_coeff_registers;
logic signed [NUM_LOAD_MULT_TERMS - 1: 0] [MULT_BIT_WIDTH - 1: 0] mult_out;
logic signed [NUM_TOTAL_TERMS - 1: 0] [AUDIO_WORD_WIDTH - 1: 0] audio_sample_buffer;

logic [1:0] tree_accum_wait_count;

//Tree Accum - Stage A
localparam TREE_ACCUMA_OUTPUT_WIDTH = 59 + 1;

logic signed [NUM_LOAD_MULT_TERMS - 1: 0] [TREE_ACCUMA_OUTPUT_WIDTH - 1: 0] tree_accuma_out_registers;
logic signed [TREE_ACCUMA_OUTPUT_WIDTH - 1: 0] tree_accuma_out_temp;
logic [$clog2(NUM_LOAD_MULT_TERMS) - 1: 0] accuma_cycle_count;
logic a_ready_in, accuma_busy, accuma_valid_out;

logic signed [4 - 1: 0] [56 + 1: 0] reg_sum_stage1a;       //4 57-bits
logic signed [2 - 1: 0] [56 + 2: 0] reg_sum_stage2a;       //2 58-bits

logic signed [4 - 1: 0] [59 + 1: 0] reg_sum_stage1b;
logic signed [2 - 1: 0] [59 + 2: 0] reg_sum_stage2b;


fir_tree_accum_8 #(
    .TAP_INPUT_WIDTH(MULT_BIT_WIDTH),
    .NUM_TAP_INPUTS(8),
    .OUTPUT_BIT_WIDTH(TREE_ACCUMA_OUTPUT_WIDTH)
)
    tree_stage_a (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .tap_values_in(mult_out),
    .reg_sum_stage1(reg_sum_stage1a),
    .reg_sum_stage2(reg_sum_stage2a),
    .ready(a_ready_in),
    .tree_accum_busy(accuma_busy),
    .valid_out(accuma_valid_out),
    .accum_out(tree_accuma_out_temp) //tree_accuma_out_registers[accuma_cycle_count]
    );


//Tree Accum - Stage B
// localparam NUM_ACCUMB_TERMS = 8; //num stage B inputs
localparam NUM_ACCUMC_TERMS = 4; //num stage C inputs
localparam TREE_ACCUMB_OUTPUT_WIDTH = 64;

logic signed [NUM_ACCUMC_TERMS - 1: 0] [TREE_ACCUMB_OUTPUT_WIDTH - 1: 0] tree_accumb_out_registers;
logic signed [TREE_ACCUMB_OUTPUT_WIDTH - 1: 0] tree_accumb_out_temp;
logic [$clog2(NUM_ACCUMC_TERMS) - 1: 0] accumb_cycle_count; //leaf count
logic b_ready_in, accumb_busy, accumb_valid_out;

logic test_a;
logic  [$clog2(200) - 1: 0] test_b;


fir_tree_accum_8 #(  
    .TAP_INPUT_WIDTH(TREE_ACCUMA_OUTPUT_WIDTH),
    .NUM_TAP_INPUTS(8),
    .OUTPUT_BIT_WIDTH(TREE_ACCUMB_OUTPUT_WIDTH)
    ) tree_stage_b (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .tap_values_in(tree_accuma_out_registers),
    .reg_sum_stage1(reg_sum_stage1b),
    .reg_sum_stage2(reg_sum_stage2b),
    .ready(b_ready_in),
    .tree_accum_busy(accumb_busy),
    .valid_out(accumb_valid_out),
    .accum_out(tree_accumb_out_temp) //tree_accumb_out_registers[accumb_cycle_count]
    );

//Tree Accum - Stage C

localparam TREE_ACCUMC_OUTPUT_WIDTH = 67;

logic c_ready_in, accumc_busy, accumc_valid_out;

fir_tree_accum_4 #(  
    .TAP_INPUT_WIDTH(TREE_ACCUMB_OUTPUT_WIDTH),
    .NUM_TAP_INPUTS(4),
    .OUTPUT_BIT_WIDTH(TREE_ACCUMC_OUTPUT_WIDTH)
    ) tree_stage_c (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .tap_values_in(tree_accumb_out_registers), 
    .ready(c_ready_in),
    .tree_accum_busy(accumc_busy),
    .valid_out(accumc_valid_out), 
    .accum_out(fir_out) 
    );



always_ff @(posedge clk_in) begin
    if (rst_in) begin
        fir_state <= INITIAL;
        ws_buffer <= 0;
        load_count <= 0;
        total_terms_count <= 0;
        cycle_offset <= 0;
        load_mult_ix <= 0;
        mult_ix <= 0;
        load_wait <= 0;

        test_b <=0;

        audio_word_registers <= 0;
        hrir_coeff_registers <= 0;
        mult_out <= 0;
        audio_sample_buffer <= 0;

        tree_accuma_out_registers <= 0;
        accuma_cycle_count <= 0;
        a_ready_in <= 0;
        
        tree_accumb_out_registers <= 0;
        accumb_cycle_count <= 0;
        b_ready_in <= 0;

        //tree_accum_wait_count <= 0;
        c_ready_in <= 0;

        load_ready <= 1; //must set to 1 to offset by two cycles
        fir_busy <= 0;
        ws_out <= 0;
        fir_valid_out <= 0;

    end 
    else if (start) begin
        
        case (fir_state)
        INITIAL: begin
            //investigate this logic
            ws_buffer <= ws_in;
            if (ws_in != ws_buffer) begin 
                fir_state <= LOAD;
            end
        end

        LOAD: begin
            
            // if (!load_wait) load_wait <= 1; //wait one more cycle for BRAM reads to be valid
            // else begin
            fir_busy <= 1;
            if (total_terms_count < NUM_TOTAL_TERMS) begin //changed from NUM_TOTAL_TERMS - 1
                //test_a <= 1;
                //load in new sample
                audio_word_registers[(NUM_LOAD_MULT_TERMS - 1)] <= audio_sample_in; //always inserting at "MSB" section of packed array
                hrir_coeff_registers[(NUM_LOAD_MULT_TERMS - 1)] <= coeff_in;
                audio_sample_buffer[(NUM_TOTAL_TERMS - 1)] <= audio_sample_in; //always need to stream in 200 new hrir coeffs every time

                for (int pipe_ix = NUM_LOAD_MULT_TERMS - 1; pipe_ix > 0; pipe_ix--) begin
                    audio_word_registers[pipe_ix - 1] <= audio_word_registers[pipe_ix];
                    hrir_coeff_registers[pipe_ix - 1] <= hrir_coeff_registers[pipe_ix];
                end

                //NOTE: in order to properly pipeline audio_sample_buffer, would need a for loop that is 200 iterations long
                // wrong: audio_sample_buffer[total_terms_count] <= audio_sample_in;
                test_b <= test_b + 1 ;
            end else begin
                for (int pipe_ix = 0; pipe_ix < NUM_LOAD_MULT_TERMS; pipe_ix++) begin
                    audio_word_registers[pipe_ix] <= 0;
                    hrir_coeff_registers[pipe_ix] <= 0;
                end
                 //last 256 - 200 = 56 
            end

            //load in 8 samples over 8 cycles
            if (load_mult_ix < NUM_LOAD_MULT_TERMS - 1) load_mult_ix <= load_mult_ix + 1; 
            else if (load_mult_ix == NUM_LOAD_MULT_TERMS - 1) begin
                load_mult_ix <= 0;
                fir_state <= MULTIPLY;
            end

            // audio_word_registers[(NUM_LOAD_MULT_TERMS - 1) - load_mult_ix - 1] <= audio_word_registers[(NUM_LOAD_MULT_TERMS - 1) - load_mult_ix];
            // hrir_coeff_registers[(NUM_LOAD_MULT_TERMS - 1) - load_mult_ix - 1] <= hrir_coeff_registers[(NUM_LOAD_MULT_TERMS - 1 )- load_mult_ix];

            total_terms_count <= total_terms_count + 1;
            
        end

        MULTIPLY: begin
            a_ready_in <= 1;
            
            for (int mult_ix = 0; mult_ix < NUM_LOAD_MULT_TERMS; mult_ix++) begin //8 parallel multiplications in one stage
                //signed multiplication with 0s doesn't work well
                //orig 200-long registers needd:  + cycle_offset * NUM_LOAD_MULT_TERMS (but since we keep recycling, not needed)
                if (audio_word_registers[mult_ix] == 0 || hrir_coeff_registers[mult_ix] == 0)  mult_out[mult_ix] <= 0;
                else mult_out[mult_ix] <= $signed(audio_word_registers[mult_ix]) * $signed(hrir_coeff_registers[mult_ix]);
            end

            

            //flush (optional)
            audio_word_registers <= 0;
            hrir_coeff_registers <= 0;
        
            fir_state <= TREE_ACCUMA;
            

        end

        TREE_ACCUMA: begin
            
            
            a_ready_in <= 0;
            if (accuma_valid_out) begin //tree accuma output something

                case (accuma_cycle_count)
                    0: tree_accuma_out_registers[0] <= tree_accuma_out_temp;
                    1: tree_accuma_out_registers[1] <= tree_accuma_out_temp;
                    2: tree_accuma_out_registers[2] <= tree_accuma_out_temp;
                    3: tree_accuma_out_registers[3] <= tree_accuma_out_temp;
                    4: tree_accuma_out_registers[4] <= tree_accuma_out_temp;
                    5: tree_accuma_out_registers[5] <= tree_accuma_out_temp;
                    6: tree_accuma_out_registers[6] <= tree_accuma_out_temp;
                    7: tree_accuma_out_registers[7] <= tree_accuma_out_temp;
                    default: tree_accuma_out_registers[accuma_cycle_count] <= 0;
                endcase

                if (accuma_cycle_count < NUM_LOAD_MULT_TERMS - 1 ) begin //8
                    accuma_cycle_count <= accuma_cycle_count + 1; 
                    fir_state <= LOAD;
                end
                else begin
                    mult_out <= 0; //flush (optional)
                    accuma_cycle_count <= 0;

                    fir_state <= TREE_ACCUMB; //8 stored, go to next
                    
                    b_ready_in <= 1;
                end 

                
            end 
            // else if (tree_accuma_out_registers[accuma_cycle_count]) 

            

            
        end

        TREE_ACCUMB: begin
            //need to wait 3 cycles (tree_accumb module)
            // if (tree_accum_wait_count < $clog2(NUM_LOAD_MULT_TERMS) - 1) tree_accum_wait_count <= tree_accum_wait_count + 1;
            // else begin 
            //     tree_accum_wait_count <= 0;

                // tree_accumb_out_registers[0] <= 1;
            b_ready_in <= 0;
            if (accumb_valid_out) begin
                case (accumb_cycle_count)
                    0: tree_accumb_out_registers[0] <= tree_accumb_out_temp;
                    1: tree_accumb_out_registers[1] <= tree_accumb_out_temp;
                    2: tree_accumb_out_registers[2] <= tree_accumb_out_temp;
                    3: tree_accumb_out_registers[3] <= tree_accumb_out_temp;
                    // default: tree_accumb_out_registers[accumb_cycle_count] <= 0;
                endcase

                

                if (accumb_cycle_count < NUM_ACCUMC_TERMS - 1) begin //4
                    accumb_cycle_count <= accumb_cycle_count + 1; 
                    fir_state <= LOAD;
                end
            
                else begin
                    

                    accumb_cycle_count <= 0;
                    fir_state <= TREE_ACCUMC; //4 stored, go to next
                    
                    c_ready_in <= 1;
                end
                tree_accuma_out_registers <= 0; //flush (optional)
            end
                
            // end
        end
        
        TREE_ACCUMC: begin
            //need to wait 2 cycles (tree_accumc module)
            // if (tree_accum_wait_count < $clog2(NUM_LOAD_MULT_TERMS) - 2) tree_accum_wait_count <= tree_accum_wait_count + 1;
            // else begin 
            //     tree_accum_wait_count <= 0;
            c_ready_in <= 0;
            if (accumc_valid_out) begin
                load_ready <= 0; //stop issuing BRAM read requests
                fir_valid_out <= 1;
                ws_out <= !ws_buffer;
                fir_state <= INITIAL;
                
                fir_busy <= 0;
            end
        end
            

        endcase



    end
end


endmodule