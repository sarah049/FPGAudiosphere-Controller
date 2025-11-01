module fir_tree #(

) (

),
// *********************************** FIR: Mult BRAM Stages ******************************* //



// ***************************************************************************************** //

// *********************************** FIR: Tree Accumulation Stages ******************************* //
  
  //Stage A
  localparam NUM_TREE_ACCUMA = 13;
  localparam TREE_ACCUMA_OUTPUT_WIDTH = 60;
  localparam ACCUMA_CLK_DURATION = ;

  logic accuma_last_tree;
  logic [NUM_TREE_ACCUMA - 1:0] [TREE_ACCUMA_OUTPUT_WIDTH - 1: 0] tree_accuma_out_registers;
  logic accuma_valid_out;
  
  logic accumb_valid_out;
  logic [FIR_OUT_WIDTH - 1: 0] tree_accumb_out;

  for (int i = 0 ; i < NUM_TREE_ACCUMA; i++) begin //tree #
    always_comb begin
        if (i < NUM_TREE_ACCUMA - 1) accuma_last_tree = 0;
        else accuma_last_tree = 1;
    end

    fir_tree_accum #(
        .TAP_INPUT_WIDTH(56),
        .NUM_CYCLES(4),
        .NUM_TAP_INPUTS(16),
        .OUTPUT_BIT_WIDTH(60)
    )
    tree_stage_a (
      .clk_in(clk_100mhz),
      .rst_in(),
      .tap_values_in(),
      .last_tree(accuma_last_tree),
      .tree_accum_busy(),
      .valid_out(accuma_valid_out),
      .accum_out(tree_accuma_out_registers[i])
    );
  end

  //add pipelining here

  //Stage B
  fir_tree_accum #(  
    .TAP_INPUT_WIDTH(60),
    .NUM_CYCLES(4),
    .NUM_TAP_INPUTS(13),
    .OUTPUT_BIT_WIDTH(64)
    ) tree_stage_b (
      .clk_in(clk_100mhz),
      .rst_in(),
      .tap_values_in(tree_accuma_out_registers),
      .last_tree(0),
      .tree_accum_busy(),
      .valid_out(accumb_valid_out),
      .accum_out(tree_accumb_out)
    );


   // *************************************************************************** //
  

  
endmodule // top_level
`default_nettype wire



