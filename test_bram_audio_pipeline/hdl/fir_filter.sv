module fir_filter #(
    parameter HRIR_COEFF_BIT_WIDTH = 32,
    parameter AUDIO_WORD_WIDTH = 24,
    parameter NUM_LOAD_MULT_TERMS = 8,
    parameter FIR_OUTPUT_BIT_WIDTH = 58, //67, //28 + 30
    parameter NUM_TOTAL_TERMS = 200
) ( 
    input wire clk_in,
    input wire rst_in,
    input wire start, // falling edge of SCK (valid_in signal)
    input wire signed [AUDIO_WORD_WIDTH - 1: 0] audio_sample_in,
    input wire signed [HRIR_COEFF_BIT_WIDTH - 1: 0] coeff_in,
    input wire ws_in, // left (0) or right (1) channel
    // input wire signed [$clog2(NUM_AZIMUTHS): 0] azimuth_in,
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

logic signed [AUDIO_WORD_WIDTH - 1: 0] audio_word_registers [NUM_LOAD_MULT_TERMS - 1: 0] ;
logic signed [HRIR_COEFF_BIT_WIDTH - 1: 0] hrir_coeff_registers [NUM_LOAD_MULT_TERMS - 1: 0] ;
logic signed [MULT_BIT_WIDTH - 1: 0] mult_out [NUM_LOAD_MULT_TERMS - 1: 0] ;
logic signed [AUDIO_WORD_WIDTH - 1: 0] audio_sample_buffer;

logic [1:0] tree_accum_wait_count;

//Tree Accum - Stage A
localparam TREE_ACCUMA_OUTPUT_WIDTH = 60;

logic signed [TREE_ACCUMA_OUTPUT_WIDTH - 1: 0] tree_accuma_out_registers [NUM_LOAD_MULT_TERMS - 1: 0] ;
logic signed [TREE_ACCUMA_OUTPUT_WIDTH - 1: 0] tree_accuma_out_temp;
logic [$clog2(NUM_LOAD_MULT_TERMS) - 1: 0] accuma_cycle_count;
logic a_ready_in, a_bram_load_ready, accuma_busy, accuma_valid_out;

// logic signed  [56 + 1: 0] reg_sum_stage1a [4 - 1: 0];       //4 57-bits
// logic signed [56 + 2: 0] reg_sum_stage2a [2 - 1: 0] ;       //2 58-bits

// logic signed [TREE_ACCUMA_OUTPUT_WIDTH + 1: 0] reg_sum_stage1b [4 - 1: 0] ;
// logic signed [TREE_ACCUMA_OUTPUT_WIDTH + 2: 0] reg_sum_stage2b [2 - 1: 0] ;


fir_tree_accum_8 #(
    .TAP_INPUT_WIDTH(MULT_BIT_WIDTH),
    .NUM_TAP_INPUTS(8),
    .OUTPUT_BIT_WIDTH(TREE_ACCUMA_OUTPUT_WIDTH)
)
    tree_stage_a (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .tap_values_in(mult_out),
    .ready(a_ready_in),
    .bram_load_ready(a_bram_load_ready),
    .tree_accum_busy(accuma_busy),
    .valid_out(accuma_valid_out),
    .accum_out(tree_accuma_out_temp) //tree_accuma_out_registers[accuma_cycle_count]
    );


//Tree Accum - Stage B
// localparam NUM_ACCUMB_TERMS = 8; //num stage B inputs
localparam NUM_ACCUMC_TERMS = 4; //num stage C inputs
localparam TREE_ACCUMB_OUTPUT_WIDTH = 64;

logic signed [TREE_ACCUMB_OUTPUT_WIDTH - 1: 0] tree_accumb_out_registers [NUM_ACCUMC_TERMS - 1: 0] ;
logic signed [TREE_ACCUMB_OUTPUT_WIDTH - 1: 0] tree_accumb_out_temp;
logic [$clog2(NUM_ACCUMC_TERMS) - 1: 0] accumb_cycle_count; //leaf count
logic b_ready_in, b_bram_load_ready, accumb_busy, accumb_valid_out;



fir_tree_accum_8 #(  
    .TAP_INPUT_WIDTH(TREE_ACCUMA_OUTPUT_WIDTH),
    .NUM_TAP_INPUTS(8),
    .OUTPUT_BIT_WIDTH(TREE_ACCUMB_OUTPUT_WIDTH)
    ) tree_stage_b (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .tap_values_in(tree_accuma_out_registers),
    .ready(b_ready_in),
    .bram_load_ready(b_bram_load_ready),
    .tree_accum_busy(accumb_busy),
    .valid_out(accumb_valid_out),
    .accum_out(tree_accumb_out_temp) //tree_accumb_out_registers[accumb_cycle_count]
    );

//Tree Accum - Stage C

localparam TREE_ACCUMC_OUTPUT_WIDTH = 67;
logic [TREE_ACCUMC_OUTPUT_WIDTH - 1 : 0] fir_out_buffer;
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
    .accum_out(fir_out_buffer) 
    );



always_ff @(posedge clk_in) begin
    if (rst_in) begin
        fir_state <= INITIAL;
        ws_buffer <= 1; //first ws_in will be 0, want it to be different
        load_count <= 0;
        total_terms_count <= 0;
        cycle_offset <= 0;
        load_mult_ix <= 0;
        mult_ix <= 0;
        load_wait <= 0;

        // audio_word_registers <= 0;
        for (int i1 = 0; i1 < NUM_LOAD_MULT_TERMS; i1 ++) begin
            audio_word_registers[i1] <= 0;
        end

        // hrir_coeff_registers <= 0;
        for (int i1 = 0; i1 < NUM_LOAD_MULT_TERMS; i1 ++) begin
            hrir_coeff_registers[i1] <= 0;
        end

        // mult_out <= 0;
        for (int i1 = 0; i1 < NUM_LOAD_MULT_TERMS; i1 ++) begin
            mult_out[i1] <= 0;
        end

        audio_sample_buffer <= 0;

        // tree_accuma_out_registers <= 0;
        for (int i1 = 0; i1 < NUM_LOAD_MULT_TERMS; i1 ++) begin
            tree_accuma_out_registers[i1] <= 0;
        end

        accuma_cycle_count <= 0;
        a_ready_in <= 0;
        
        // tree_accumb_out_registers <= 0;
        for (int i1 = 0; i1 < NUM_ACCUMC_TERMS; i1 ++) begin
            tree_accumb_out_registers[i1] <= 0;
        end 

        accumb_cycle_count <= 0;
        b_ready_in <= 0;

        c_ready_in <= 0;

        fir_out <= 0;
        load_ready <= 1; //must set to 1 to offset by two cycles
        fir_busy <= 0;
        ws_out <= 0;
        fir_valid_out <= 0;

    end 
    else begin
        
        case (fir_state)

        INITIAL: 
        if (start) begin
            //investigate this logic
            ws_buffer <= ws_in;
            if (ws_in != ws_buffer) begin //change in word select
                fir_state <= LOAD;
            end
             //always need to stream in 200 new hrir coeffs every time
        end

        LOAD: begin
            
            fir_busy <= 1;
            if (total_terms_count < NUM_TOTAL_TERMS) begin 
                //load in new sample
                audio_word_registers[(NUM_LOAD_MULT_TERMS - 1)] <= audio_sample_in; //always inserting at "MSB" section of packed array
                hrir_coeff_registers[(NUM_LOAD_MULT_TERMS - 1)] <= coeff_in;
                
                //pipeline rest of signals
                for (int pipe_ix = NUM_LOAD_MULT_TERMS - 1; pipe_ix > 0; pipe_ix--) begin
                    audio_word_registers[pipe_ix - 1] <= audio_word_registers[pipe_ix];
                    hrir_coeff_registers[pipe_ix - 1] <= hrir_coeff_registers[pipe_ix];
                end

                if (total_terms_count == 6) load_ready <= 0; //stop 2 cycles early

                if(total_terms_count == NUM_TOTAL_TERMS - 1) audio_sample_buffer <= audio_sample_in;
                
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

            total_terms_count <= total_terms_count + 1;
            
        end

        MULTIPLY: begin
            a_ready_in <= 1;
            
            for (int mult_ix = 0; mult_ix < NUM_LOAD_MULT_TERMS; mult_ix++) begin 
                if (audio_word_registers[mult_ix] == 0 || hrir_coeff_registers[mult_ix] == 0)  mult_out[mult_ix] <= 0;
                else mult_out[mult_ix] <= $signed(audio_word_registers[mult_ix]) * $signed(hrir_coeff_registers[mult_ix]);
            end

            //flush 
            // audio_word_registers <= 0;
            // hrir_coeff_registers <= 0;
        
            fir_state <= TREE_ACCUMA;
            

        end

        TREE_ACCUMA: begin
            
            a_ready_in <= 0;
            if (a_bram_load_ready) load_ready <= 1;

            if (accuma_valid_out) begin //tree accuma output something
                load_ready <= 1;
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
                    // mult_out <= 0; //flush 

                    accuma_cycle_count <= 0;

                    fir_state <= TREE_ACCUMB; //8 stored, go to next
                    
                    b_ready_in <= 1;
                end 

            end 
            
        end

        TREE_ACCUMB: begin
            
            b_ready_in <= 0;

            if (b_bram_load_ready) load_ready <= 1;

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
                // tree_accuma_out_registers <= 0; //flush (optional)
            end
            
        end
        
        TREE_ACCUMC: begin
            
            c_ready_in <= 0;
            if (accumc_valid_out) begin
                load_ready <= 0; //stop issuing BRAM read requests
                // fir_out <= fir_out_buffer;
                fir_out <=  {fir_out_buffer[TREE_ACCUMC_OUTPUT_WIDTH - 1], fir_out_buffer[FIR_OUTPUT_BIT_WIDTH - 2: 0]};
                fir_valid_out <= 1;
                ws_out <= ws_buffer;
                fir_state <= INITIAL;
                
                fir_busy <= 0;
            end
        end
            

        endcase



    end
end


endmodule
