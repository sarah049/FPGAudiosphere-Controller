module fir_filter #(
    parameter HRIR_COEFF_BIT_WIDTH = 32,
    parameter AUDIO_WORD_WIDTH = 24,
    parameter NUM_AZIMUTHS = 25,
    parameter NUM_LOAD_MULT_TERMS = 8,
    parameter FIR_OUTPUT_BIT_WIDTH = 64,
    parameter NUM_TOTAL_TERMS = 200,
) ( 
    input wire clk_in,
    input wire rst_in,
    input wire start, // falling edge of SCK 
    input wire signed [AUDIO_WORD_WIDTH - 1: 0] audio_sample_in,
    input wire signed [HRIR_COEFF_BIT_WIDTH - 1: 0] coeff_in,
    input wire ws_in, // left (0) or right (1) channel
    input wire signed [$clog2(NUM_AZIMUTHS): 0] azimuth_in,

    output wire load_ready, //initiate read from HRIR BRAM
    output wire fir_busy, //if low, in mult_stage
    output wire ws_out, //FILL in logic for this!
    output wire fir_valid_out,
    output wire signed [NUM_TOTAL_TERMS - 1: 0] [AUDIO_WORD_WIDTH - 1: 0] audio_sample_out, //200 x 24
    output wire signed [FIR_OUTPUT_BIT_WIDTH - 1: 0] fir_out
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

localparam MULT_BIT_WIDTH = HRIR_COEFF_BIT_WIDTH + AUDIO_WORD_WIDTH;
localparam NUM_MULT_CYCLES = NUM_LOAD_MULT_TERMS/NUM_MULT_PAIRS; //25

logic load_wait;
logic [$clog2(NUM_LOAD_MULT_TERMS) - 1: 0] load_count;
logic [$clog2(NUM_TOTAL_TERMS) - 1: 0] total_terms_count; //200, max 256
logic [$clog2(NUM_MULT_CYCLES) - 1: 0] cycle_offset;
logic ws_buffer;

logic [$clog2(NUM_LOAD_MULT_TERMS -1) - 1: 0] load_mult_ix;

logic signed [NUM_LOAD_MULT_TERMS - 1: 0] [AUDIO_WORD_WIDTH - 1: 0] audio_word_registers,;
logic signed [NUM_LOAD_MULT_TERMS - 1: 0] [HRIR_COEFF_BIT_WIDTH - 1: 0] hrir_coeff_registers;
logic signed [NUM_LOAD_MULT_TERMS - 1: 0] [MULT_BIT_WIDTH - 1: 0] mult_out;
logic signed [NUM_TOTAL_TERMS - 1: 0] [AUDIO_WORD_WIDTH - 1: 0] audio_sample_buffer;

//Tree Accum - Stage A
localparam TREE_ACCUMA_OUTPUT_WIDTH = 59;

logic [NUM_LOAD_MULT_TERMS - 1: 0] [TREE_ACCUMA_OUTPUT_WIDTH - 1: 0] tree_accuma_out_registers;
logic [$clog2(NUM_LOAD_MULT_TERMS) - 1: 0] accuma_cycle_count;
logic accuma_busy, accuma_valid_out;

fir_tree_accum #(
        .TAP_INPUT_WIDTH(56),
        .NUM_CYCLES(3),
        .NUM_TAP_INPUTS(8),
        .OUTPUT_BIT_WIDTH(59)
    )
    tree_stage_a (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .tap_values_in(mult_out),
    .last_tree(0),
    .tree_accum_busy(accuma_busy),
    .valid_out(accuma_valid_out),
    .accum_out(tree_accuma_out_registers[accuma_cycle_count])
    );


//Tree Accum - Stage B
localparam NUM_ACCUMB_TERMS = 4;
localparam TREE_ACCUMB_OUTPUT_WIDTH = 62;

logic [NUM_ACCUMB_TERMS - 1: 0] [TREE_ACCUMB_OUTPUT_WIDTH - 1: 0] tree_accumb_out_registers;
logic [$clog2(NUM_ACCUMB_TERMS) - 1: 0] accumb_cycle_count; //leaf count
logic accumb_busy, accumb_valid_out;

fir_tree_accum #(  
    .TAP_INPUT_WIDTH(60),
    .NUM_CYCLES(3),
    .NUM_TAP_INPUTS(8),
    .OUTPUT_BIT_WIDTH(62)
    ) tree_stage_b (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .tap_values_in(tree_accuma_out_registers),
    .last_tree(0),
    .tree_accum_busy(accumb_busy),
    .valid_out(accumb_valid_out),
    .accum_out(tree_accumb_out_registers[accumb_cycle_count])
    );

//Tree Accum - Stage C
localparam TREE_ACCUMC_OUTPUT_WIDTH = 64;

logic accumc_busy, accumc_valid_out;

fir_tree_accum #(  
    .TAP_INPUT_WIDTH(62),
    .NUM_CYCLES(2),
    .NUM_TAP_INPUTS(4),
    .OUTPUT_BIT_WIDTH(64)
    ) tree_stage_c (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .tap_values_in(tree_accumb_out_registers), 
    .last_tree(0),
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

        audio_word_registers <= 0;
        hrir_coeff_registers <= 0;
        mult_out <= 0;
        audio_sample_buffer <= 0;

        tree_accuma_out_registers <= 0;
        accuma_cycle_count <= 0;
        accuma_valid_out <= 0;
        
        tree_accumb_out_registers <= 0;
        accumb_cycle_count <= 0;
        accumb_valid_out <= 0;

        accumc_valid_out <= 0;

        load_ready <= 0;
        fir_busy <= 0;
        ws_out <= 0;
        fir_valid_out <= 0;
        fir_out <= 0;

    end else (start) begin
        
        case (fir_state)
        INITIAL: begin
            ws_buffer <= ws_in;
            if (ws_in != ws_buffer) begin 
                fir_state <= LOAD;
                load_ready <= 1;
            end
        end

        LOAD: begin
            
            if (!load_wait) load_wait <= 1; //wait one more cycle for BRAM reads to be valid
            else begin
                fir_busy <= 1;
                if (total_terms_count < NUM_TOTAL_TERMS - 1) begin
                    audio_word_registers[NUM_LOAD_MULT_TERMS - 1] <= audio_sample_in; //8 samples at a time 
                    hrir_coeff_registers[NUM_LOAD_MULT_TERMS - 1] <= coeff_in;
                    audio_sample_buffer[total_terms_count] <= audio_sample_in;
                end else begin
                    audio_word_registers[NUM_LOAD_MULT_TERMS - 1] <= 0; //last 256 - 200 = 56 
                    hrir_coeff_registers[NUM_LOAD_MULT_TERMS - 1] <= 0;
                end

                if (load_mult_ix < NUM_LOAD_MULT_TERMS - 1) load_mult_ix <= load_mult_ix + 1; //always need to stream in 200 new hrir coeffs every time
                else if (load_mult_ix == NUM_LOAD_MULT_TERMS - 1 ) begin
                    load_mult_ix <= 0;
                    fir_state <= MULTIPLY;
                end

                if (!steady_state) audio_word_registers[load_mult_ix] <= audio_word_registers[load_mult_ix+1];
                hrir_coeff_registers[load_mult_ix] <= hrir_coeff_registers[load_mult_ix+1];

                total_terms_count <= total_terms_count + 1;
            end
        end

        MULTIPLY: begin

            for (int mult_ix = 0; mult_ix < NUM_MULT_PAIRS; mult_ix++) begin //8 parallel multiplications
                mult_out[mult_ix] <= audio_word_registers[mult_ix + cycle_offset * NUM_MULT_PAIRS] * hrir_coeff_registers[mult_ix + cycle_offset * NUM_MULT_PAIRS];
            end
            

            if (cycle_offset < NUM_MULT_CYCLES - 1) cycle_offset <= cycle_offset + 1; //25
            else begin
                cycle_offset <= 0;
            end

            fir_state <= TREE_ACCUMA;

        end

        TREE_ACCUMA: begin
            //need to wait 3 cycles (tree_accuma module)


            if (accuma_cycle_count < NUM_LOAD_MULT_TERMS - 1) begin //8
                accuma_cycle_count <= accuma_cycle_count + 1; 
                fir_state <= LOAD;
            end
            else begin
                accuma_cycle_count <= 0;
                fir_state <= TREE_ACCUMB; //8 stored, go to next
            end

        end

        TREE_ACCUMB: begin
            //need to wait 2 cycles (tree_accuma module)

            if (accumb_cycle_count < NUM_ACCUMB_TERMS - 1) begin //4
                accumb_cycle_count <= accumb_cycle_count + 1; 
                fir_state <= LOAD;
            end
            else begin
                accumb_cycle_count <= 0;
                fir_state <= TREE_ACCUMC; //4 stored, go to next
            end
            
        end
        
        TREE_ACCUMC: begin

            load_ready <= 0; //stop issuing BRAM read requests
            fir_valid_out <= 1;
            ws_out <= !ws_buffer;
            fir_state <= INITIAL;

        end
            

        endcase



    end
end


endmodule
