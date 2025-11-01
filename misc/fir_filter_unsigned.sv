module fir_filtero2 #(
    parameter NUM_AUDIO_SAMPLES = NUM_HRIR_COEFF = 200,
    parameter AUDIO_WORD_WIDTH = 16,
    parameter HRIR_COEFF_BIT_WIDTH = 32, // x 10^8 = bit shift of 30 -> round to 32 
    parameter BIT_SHIFT = 30
)(
    input logic clk_in,
    input logic rst_in,
    input logic [NUM_HRIR_COEFF - 1:0] [HRIR_COEFF_BIT_WIDTH - 1: 0] hrir_coeffs, //from BRAM, 200 entries, 32 bits each (azimuth already chosen)
    input logic [NUM_AUDIO_SAMPLES - 1:0] audio_samples, //from BRAM
    output logic fir_busy,
    output logic [OUTPUT_WIDTH - 1:0] dout, 
);
    localparam SINGLE_TERM_WIDTH = AUDIO_WORD_WIDTH * HRIR_COEFF_BIT_WIDTH; //24*32

    //bit widths for intermediary stages
    localparam QUINTET_ACCUM_WIDTH_STAGE1 = AUDIO_WORD_WIDTH * HRIR_COEFF_BIT_WIDTH + 4, // 5 terms of added multip terms
    localparam QUINTET_ACCUM_WIDTH_STAGE2 = QUINTET_ACCUM_WIDTH_STAGE1 + 4,
    localparam QUARTET_ACCUM_WIDTH_STAGE3 = QUINTET_ACCUM_WIDTH_STAGE2 + 3,
    localparam OUTPUT_WIDTH = QUARTET_ACCUM_WIDTH_STAGE3 + 1,

    //number of accumulate terms
    localparam NUM_ACCUM_TERMS_STAGE1 = 40;
    localparam NUM_ACCUM_TERMS_STAGE2 = 8;
    localparam NUM_ACCUM_TERMS_STAGE3 = 2;

    //stage 1: add in groups of 5 -> 40 accumulate terms
    logic [NUM_ACCUM_TERMS_STAGE1 - 1:0] [QUINTET_ACCUM_WIDTH_STAGE1 - 1: 0] acc_terms1;
    //stage 2: add in groups of 5 -> 8 accumulate terms
    logic [NUM_ACCUM_TERMS_STAGE2 - 1:0] [QUINTET_ACCUM_WIDTH_STAGE2 - 1: 0] acc_terms1;
    //stage 3: add in groups of 4 -> 2 accumulate terms
    logic [NUM_ACCUM_TERMS_STAGE3 - 1:0] [QUARTET_ACCUM_WIDTH_STAGE3 - 1: 0] acc_terms1;
    //stage 4: add 2 rem accumulate terms and left shift by BIT_SHIFT
    
    logic [NUM_AUDIO_SAMPLES - 1: 0][SINGLE_TERM_WIDTH - 1: 0] temp_mult_terms;
    logic prev_fir_busy;

    typedef enum {
        TERM_MULT,
        ACCUM_STAGE1,
        ACCUM_STAGE2,
        ACCUM_STAGE3,
        OUTPUT
    } fir_states;
    fir_states state;
    

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            prev_fir_busy <= 0;
            fir_busy <= 0;
            dout <= 0;
        end else begin
            case (state) 
            TERM_MULT: begin

                if (!prev_fir_busy) begin
                    prev_fir_busy <= 1;
                    fir_busy <= 1;
                end

                for (int i = 0; i < NUM_AUDIO_SAMPLES; i++) begin
                    temp_mult_terms[i] <= hrir_coeffs[i] * audio_samples[i];
                end

            end

            ACCUM_STAGE1: begin
                for (int i = 0; i < NUM_ACCUM_TERMS_STAGE1; i++) begin
                    acc_terms1[i] <= temp_mult_terms[5*i] + temp_mult_terms[5*i + 1] + temp_mult_terms[5*i + 2] + temp_mult_terms[5*i + 3] + temp_mult_terms[5*i + 4];
                end
            end

            ACCUM_STAGE2: begin
                for (int i = 0; i < NUM_ACCUM_TERMS_STAGE2; i++) begin
                    acc_terms2[i] <= temp_mult_terms[5*i] + temp_mult_terms[5*i + 1] + temp_mult_terms[5*i + 2] + temp_mult_terms[5*i + 3] + temp_mult_terms[5*i + 4];
                end
            end

            ACCUM_STAGE3: begin
                for (int i = 0; i < NUM_ACCUM_TERMS_STAGE3; i++) begin
                    acc_terms3[i] <= temp_mult_terms[4*i] + temp_mult_terms[4*i + 1] + temp_mult_terms[4*i + 2] + temp_mult_terms[4*i + 3];
                end
            end

            OUTPUT: begin
                dout <= ((acc_terms3[0] + acc_terms3[1]) >> BIT_SHIFT);
                prev_fir_busy <= 0;
                fir_busy <= 0;
            end


            endcase

        end


    end
endmodule