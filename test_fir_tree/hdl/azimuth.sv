module azimuth #(
    parameter NUM_AZIMUTHS = 25
)(
    input wire clk_in,
    input wire rst_in,
    input wire left_btn,
    input wire right_btn,

    output logic [$clog2(NUM_AZIMUTHS):0] azimuth_out 
);

    logic signed [$clog2(NUM_AZIMUTHS):0] azimuth, neg_one;
    logic db_btn_out1, db_btn_out2;
    assign neg_one = 5'b11111;

    always_ff @(posedge clk_in) begin
      if (rst_in) begin 
        azimuth <= 0;
      end else begin
        if (left_btn) begin
          if (azimuth == 0) azimuth <= NUM_AZIMUTHS - 1;
          else azimuth <= azimuth + neg_one;
        end else if (right_btn) begin
          if (azimuth == NUM_AZIMUTHS - 1) azimuth <= 0;
          else azimuth <= azimuth + 1;
        end

      end
    end
assign azimuth_out = azimuth;
endmodule