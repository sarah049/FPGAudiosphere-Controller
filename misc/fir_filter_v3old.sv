module fir_filter #(
    parameter HRIR_COEFF_BIT_WIDTH = 32;
    parameter AUDIO_WORD_WIDTH = 24,
    parameter OUTPUT_BIT_WIDTH = HRIR_COEFF_BIT_WIDTH + AUDIO_WORD_WIDTH,
    parameter NUM_AZIMUTHS = 25,
    parameter NUM_TERMS = 200,
    parameter NUM_MULT_PAIRS = 8,
    parameter NUM_MULT_CYCLES = NUM_TERMS/NUM_MULT_PAIRS //25
) ( 
    input wire clk_in,
    input wire rst_in,
    input wire start, // falling edge of SCK ``````````````````````````````
    input wire signed [AUDIO_WORD_WIDTH - 1: 0] audio_sample_in,
    input wire signed [HRIR_COEFF_BIT_WIDTH - 1: 0] coeff_in,
    input wire ws_in, // left (0) or right (1) channel
    input wire [$clog2(NUM_AZIMUTHS) - 1: 0] azimuth_in,
    output wire mult_busy, //if low, in mult_stage
    output wire ws_out,
    output wire signed [AUDIO_WORD_WIDTH - 1: 0] audio_sample_out,
    output wire signed [NUM_MULT_PAIRS - 1: 0] [OUTPUT_BIT_WIDTH - 1: 0] mult_out
);

typedef enum { 
    LOAD,
    MULTIPLY,
    TREE_ACCUMA,
    TREE_ACCUMB,
    TREE_ACCUMC
} mult_states;

mult_states mult_state;

logic steady_state;
logic [$clog2(NUM_TERMS) - 1: 0] load_count; 
logic [$clog2(NUM_MULT_CYCLES) - 1: 0] cycle_offset;

logic signed [NUM_TERMS - 1: 0] [AUDIO_WORD_WIDTH - 1: 0] audio_word_registers;
logic signed [NUM_TERMS - 1: 0] [HRIR_COEFF_BIT_WIDTH - 1: 0] hrir_coeff_registers;


//Tree Accum - Stage A
// localparam NUM_TREE_ACCUMA = 32;
localparam TREE_ACCUMA_OUTPUT_WIDTH = 59;

logic accuma_last_tree;
logic [TREE_ACCUMA_OUTPUT_WIDTH - 1: 0] tree_accuma_out_register;
logic accuma_valid_out;

//Tree Accum - Stage B
// localparam NUM_TREE_ACCUMB = 8;
localparam TREE_ACCUMB_OUTPUT_WIDTH = 62;

logic [TREE_ACCUMB_OUTPUT_WIDTH - 1: 0] tree_accumb_out_register;
logic accumb_valid_out;

//Tree Accum - Stage C
// localparam NUM_TREE_ACCUMC = 4;
localparam TREE_ACCUMC_OUTPUT_WIDTH = 64;

logic [TREE_ACCUMC_OUTPUT_WIDTH - 1: 0] tree_accumc_out_register;
logic accumc_valid_out;
// logic [FIR_OUT_WIDTH - 1: 0] tree_accumc_out;



always_ff @(posedge clk_in) begin
    if (rst_in) begin
        audio_word_registers <= 0;
        hrir_coeff_registers <= 0;
        mult_state <= LOAD;
        steady_state <= 0;

        cycle_offset <= 0;
        valid_write <= 0;

        mult_busy <= 0;
        mult_out <= 0;

    end else (start) begin
        
        case (mult_state)

        LOAD: begin
            mult_busy <= 1;
            audio_word_registers[NUM_TERMS - 1] <= audio_sample_in; //won't always need 200 new samples 
            hrir_coeff_registers[NUM_TERMS - 1] <= coeff_in;

            for (int i = 0; i < NUM_TERMS - 1; i++) begin //always need to stream in 200 new hrir coeffs every time
                if (!steady_state) audio_word_registers[i] <= audio_word_registers[i+1];
                hrir_coeff_registers[i] <= hrir_coeff_registers[i+1];
            end

            if (!steady_state) load_count <= load_count + 1;
            else if (load_count == NUM_TERMS - 1) begin //i.e. steady state reached
                //note: after first 200 loads, will only need 1 audio samples and 200  per 2200cycles
                steady_state <= 1;
                mult_state <= MULTIPLY;
            end

        end

        MULTIPLY: begin
            // valid_write <= 1;
            for (int i = 0; i < NUM_MULT_PAIRS - 1; i++) begin //8
                mult_out[i] <= audio_word_registers[i + cycle_offset * NUM_MULT_PAIRS] * hrir_coeff_registers[i + cycle_offset * NUM_MULT_PAIRS];
            end

            if (cycle_offset < NUM_MULT_CYCLES) cycle_offset <= cycle_offset + 1;
            else begin
                cycle_offset <= 0;
                mult_state <= LOAD;
                
            end

        end

        TREE_ACCUMA: begin
            
            fir_tree_accum #(
                .TAP_INPUT_WIDTH(56),
                .NUM_CYCLES(3),
                .NUM_TAP_INPUTS(8),
                .OUTPUT_BIT_WIDTH(59)
            )
            tree_stage_a (
            .clk_in(clk_in),
            .rst_in(),
            .tap_values_in(mult_out),
            .last_tree(),
            .tree_accum_busy(),
            .valid_out(accuma_valid_out),
            .accum_out(tree_accuma_out_register)
            );
        end

        

        TREE_ACCUMB: begin
            
            fir_tree_accum #(  
            .TAP_INPUT_WIDTH(60),
            .NUM_CYCLES(3),
            .NUM_TAP_INPUTS(8),
            .OUTPUT_BIT_WIDTH(62)
            ) tree_stage_b (
            .clk_in(clk_in),
            .rst_in(),
            .tap_values_in(tree_accuma_out_register),
            .last_tree(accumb_last_tree),
            .tree_accum_busy(),
            .valid_out(accumb_valid_out),
            .accum_out(tree_accumb_out_register)
            );
            
        end
        

        TREE_ACCUMC: begin
            fir_tree_accum #(  
            .TAP_INPUT_WIDTH(62),
            .NUM_CYCLES(2),
            .NUM_TAP_INPUTS(4),
            .OUTPUT_BIT_WIDTH(64)
            ) tree_stage_c (
            .clk_in(clk_in),
            .rst_in(),
            .tap_values_in(), //tree_accuma_out_registers
            .last_tree(0),
            .tree_accum_busy(),
            .valid_out(accumc_valid_out), //accumb_valid_out
            .accum_out(tree_accumc_out_register) //tree_accumb_out
            );
        end
            

        endcase



    end
end


endmodule

// ******* MULTIPLY STAGE to MULT BRAM Write ******* //

//   logic [OUTPUT_BIT_WIDTH-1:0] dina; // 
//   logic                 valid_write; // 
//   logic [$clog2(NUM_TERMS)-1:0]      addra; // counts to 200 mult terms

// MULTIPLICATION BRAM - stores multiplication terms going into TREE ACCUM //
// xilinx_true_dual_port_read_first_2_clock_ram #(
//     .RAM_WIDTH(OUTPUT_BIT_WIDTH), 
//     .RAM_DEPTH(NUM_TERMS)
// ) fir_mult_bram
//   (
//   // PORT A - Writes
//     .addra(addra), .dina(dina), .clka(clk_in),
//     .wea(1'b1), .ena(valid_write), .rsta(rst_in),
//     .regcea(1'b1), .douta(),
  
//   // PORT B - Reads
//     .addrb(addrb), .dinb(0), .clkb(clk_in),
//     .web(1'b0), .enb(ready_read), .rstb(rst_in),
//     .regceb(1'b1), .doutb(doutb)
//   );