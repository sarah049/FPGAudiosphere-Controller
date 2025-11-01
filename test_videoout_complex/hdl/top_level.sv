`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
    // System
    input wire clk_100mhz_sys,
    input wire [3:0] btn,

    // I2S IO
    input wire fsync_rxd,
    input wire sck_rxd,
    input wire ws_rxd,
    input wire sd_rxd,

    output logic sys_rxd_clk,

    output logic sck_txd_clk,
    output logic ws_txd_clk,
    output logic sd_txd,

    // HDMI IO
    output logic [2:0]  hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
    output logic [2:0]  hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
    output logic        hdmi_clk_p, hdmi_clk_n, //differential hdmi clock

    //AZIMUTH/HRIR IO
    input wire [15:0]   sw
  );



  // Ground Truth.
  localparam AUDIO_WORD_WIDTH = 24;
  typedef enum logic {WAIT_SAMPLES = 1'b0, STREAMING = 1'b1} streaming_states; streaming_states streaming_state; 
  initial streaming_state = WAIT_SAMPLES;

  //  Clock signals
  logic clk_100mhz, clk_pixel, clk_5x;
  cw_hdmi_clk_wiz wizard_hdmi(.sysclk(clk_100mhz), .clk_pixel(clk_pixel), .clk_tmds(clk_5x), .reset(0));
  cw_fast_clk_wiz wizard_migcam(.clk_in1(clk_100mhz_sys), .clk_100(clk_100mhz), .reset(0));
  

  // System & High Level
  logic new_window;              // Beginning ~2200 cycle audio sample frame 
  logic last_cycle_window;       // Last cycle in ~2200 window
  logic last_cycle_bit;          // Within serial clock, last sysclk cycle, next sysclk cycle should have new bit 
  logic start;                   // Start ~2200 cycle processing

  logic sys_rst;                 // Reset entire pipeline
  assign sys_rst = btn[0];

  logic pixel_rst;
  assign pixel_rst = btn[0];

  logic audio_bitrate_sck_clk;   // ~2.1168 MHz for bitrate
  logic   audio_sample_ws_clk;   // ~44.1 KHz clk for bounding audio samples

  assign sck_txd_clk = audio_bitrate_sck_clk;
  assign ws_txd_clk = audio_sample_ws_clk;

  // clock generator module for ~44.1 kHz ws_txd and 2.198 MHz sck_txds
  audio_rate_clk_gen clk_gen (.clk_in(clk_100mhz), .rst_in(sys_rst), .clk_ws(audio_sample_ws_clk), .clk_sck(audio_bitrate_sck_clk), .new_window(new_window), .last_cycle(last_cycle_window), .last_cycle_bit(last_cycle_bit));
  
  //clock wizard module with sys_rxd_clk as output ...  44.1 kHz fs -> 11.2896 MHz
  clk_wiz_0 clk_gen_1 (.clk_in1(clk_100mhz), .clk_out1(sys_rxd_clk), .reset(sys_rst));

  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Module Interaction Below ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ //



  // *********************************** I2S RXD ******************************* //

  logic [AUDIO_WORD_WIDTH-1:0] data_rxd;
  logic channel_rxd;
  logic valid_rxd;

  logic fsync_rxd_buffer, sck_rxd_buffer, ws_rxd_buffer, sd_rxd_buffer;
  i2s_buffer   buffer   (.clk_in(clk_100mhz), .rst_in(sys_rst), .fsync_in(fsync_rxd), .sck_in(sck_rxd), .ws_in(ws_rxd), .sd_in(sd_rxd), .fsync_out(fsync_rxd_buffer), .sck_out(sck_rxd_buffer), .ws_out(ws_rxd_buffer), .sd_out(sd_rxd_buffer));
  i2s_receiver audio_in (.clk_in(clk_100mhz), .rst_in(sys_rst), .fsync(fsync_rxd_buffer), .sck(sck_rxd_buffer), .ws(ws_rxd_buffer), .sd(sd_rxd_buffer),  .data_out(data_rxd), .channel_out(channel_rxd), .valid_out(valid_rxd));    

  // *************************************************************************** //
  
  // ************************ Data Processing Stand In ******(****************** //

  logic [AUDIO_WORD_WIDTH-1:0] data_final_left;
  logic [AUDIO_WORD_WIDTH-1:0] data_final_right;
  
  always_ff @(posedge clk_100mhz) begin
    if(valid_rxd) begin
      data_final_left  <= (channel_rxd)  ? data_rxd : data_final_left;
      data_final_right <= (!channel_rxd) ? data_rxd : data_final_right;
    end
  end

  // *************************************************************************** //

  // *********************************** I2S TXD ******************************* //
  i2s_transmitter audio_out(.clk_in(clk_100mhz), .rst_in(sys_rst), .data_left(data_final_left), 
  .data_right(data_final_right), .data_valid(1), .on_last_cycle(last_cycle_window), .on_last_cycle_bit(last_cycle_bit),
  .sclk(audio_bitrate_sck_clk), .ws(audio_sample_ws_clk), .sd(sd_txd));
  // *************************************************************************** //



  // *************************** Video Controller ************************ // 
  //                  !!!!!!!!! TIME DOMAIN CROSSING !!!!!!!!!             //
  video_controller video_control(
  .clk_100mhz(clk_100mhz), .clk_pixel(clk_pixel), .clk_5x(clk_5x), .rst_in(pixel_rst),                 // System
  .last_cycle_audio(last_cycle_window), .data_valid(1),                                                // Control
  .og_data(data_final_left), .left_data(data_final_left), .right_data(data_final_right),               // Data
  .hdmi_tx_p(hdmi_tx_p), .hdmi_tx_n(hdmi_tx_n), .hdmi_clk_p(hdmi_clk_p), .hdmi_clk_n(hdmi_clk_n));     // HDMI

  // *************************************************************************** //

endmodule // top_level
`default_nettype wire





