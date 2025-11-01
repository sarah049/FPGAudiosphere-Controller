module test_pattern_generator(
  input wire [10:0] hcount_in,
  input wire [9:0] vcount_in,
  output logic [7:0] red_out,
  output logic [7:0] green_out,
  output logic [7:0] blue_out
  );
    //your code here.
    always_comb begin
      red_out = hcount_in[7:0];
      green_out = vcount_in[7:0];
      blue_out = vcount_in[7:0] + hcount_in[7:0];
    end

endmodule