module azimuth #(parameter NUM_AZIMUTHS = 25)(
    input wire clk_in,
    input wire rst_in,
    input wire left_btn,
    input wire right_btn,

    output logic [$clog2(NUM_AZIMUTHS)-1:0] azimuth_out 
);


    logic [$clog2(NUM_AZIMUTHS)-1:0] azimuth;
    logic db_btn_out1, db_btn_out2;
    // assign neg_one = 5'b11111;

    always_ff @(posedge clk_in) begin
      if (rst_in) begin 
        azimuth <= 0;
      end else begin
        if (left_btn) begin
          if (azimuth == 0) azimuth <= NUM_AZIMUTHS - 1;
          else azimuth <= azimuth - 1;
        end else if (right_btn) begin
          if (azimuth == NUM_AZIMUTHS - 1) azimuth <= 0;
          else azimuth <= azimuth + 1;
        end

      end
    end

assign azimuth_out = azimuth;
endmodule


// else if (fir_valid_out) begin 

//         if (!ws_out) begin 
//           left_out <= fir_out[FIR_OUT_WIDTH - 1: FIR_OUT_WIDTH - 1 - AUDIO_WORD_WIDTH]; //top 24 bits = most info
//           mid_wave_switch <= 1;
//         end
//         else begin 
//           right_out <= fir_out[FIR_OUT_WIDTH - 1: FIR_OUT_WIDTH - 1 - AUDIO_WORD_WIDTH];
//           mid_wave_switch <= 0;
//         end

//       end
//       else if (mid_wave_switch) mid_wave_switch <= 0; //ensures mid_wave_switch is only high for one cycle
    