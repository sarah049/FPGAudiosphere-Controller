`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
    // System
    input wire clk_100mhz,
    input wire [3:0] btn,
    // I2S IO
    output logic sck_txd_clk,
    output logic ws_txd_clk,
    output logic sd_txd
  );



  // System & High Level
  logic new_window;        // Beginning ~2200 cycle audio sample frame 
  logic last_cycle_window; // Last cycle in ~2200 window
  logic last_cycle_bit;    // Within serial clock, last sysclk cycle, next sysclk cycle should have new bit 

  logic start;             // Start ~2200 cycle processing
  logic sys_rst;           // Reset entire pipeline
  assign sys_rst = btn[0];
 
  logic audio_bitrate_sck_clk;   // ~2.1168 MHz for bitrate
  logic   audio_sample_ws_clk;   // ~44.1 KHz clk for bounding audio samples

  assign sck_txd_clk = audio_bitrate_sck_clk;
  assign ws_txd_clk = audio_sample_ws_clk;
  audio_rate_clk_gen clk_gen (.clk_in(clk_100mhz), .rst_in(sys_rst), .clk_ws(audio_sample_ws_clk), .clk_sck(audio_bitrate_sck_clk), 
  .new_window(new_window), .last_cycle(last_cycle_window), .last_cycle_bit(last_cycle_bit));


  logic signed [23:0] out;
  logic state;


  always_ff @(posedge clk_100mhz) begin
    if(sys_rst) begin
      out <= 0;
      state <= 0;
    end else begin
      if(last_cycle_window) begin
        out   <= (state) ? out - 32 : out + 32;
        state <= (out > 1048576 || out < -1048576) ? ~state : state;
      end   
    end
  end



  // *********************************** I2S TXD ******************************* //
  i2s_transmitter audio_out(.clk_in(clk_100mhz), .rst_in(sys_rst), .data_left(out), 
                            .data_right(out), .data_valid(1), .on_last_cycle(last_cycle_window), .on_last_cycle_bit(last_cycle_bit),
                            .sclk(audio_bitrate_sck_clk), .ws(audio_sample_ws_clk), .sd(sd_txd));
  // *************************************************************************** //


endmodule // top_level
`default_nettype wire





