`default_nettype none
module video_controller(
    //System
    input wire clk_in,
    input wire rst_in,

    //IO
    output logic [2:0]  hdmi_tx_p, 
    output logic [2:0]  hdmi_tx_n, 
    output logic        hdmi_clk_p, hdmi_clk_n

);


  //  Clock signals  //
  logic clk_pixel;
  logic clk_5x;

  cw_hdmi_clk_wiz wizard_hdmi(
  .sysclk(clk_in),
  //.sysclk(clk_100_passthrough),
  .clk_pixel(clk_pixel),
  .clk_tmds(clk_5x),
  .reset(0));

  //  Video signal generator signals  //
  logic             hsync_hdmi;
  logic             vsync_hdmi;
  logic [10:0]     hcount_hdmi;
  logic [9:0]      vcount_hdmi;
  logic       active_draw_hdmi;
  logic         new_frame_hdmi;
  logic [5:0] frame_count_hdmi;
  logic                nf_hdmi;
  logic [7:0]          red,green,blue;

  video_sig_gen vsg(
  .pixel_clk_in(clk_pixel),
  .rst_in(rst_in),
  .hcount_out(hcount_hdmi),
  .vcount_out(vcount_hdmi),
  .vs_out(vsync_hdmi),
  .hs_out(hsync_hdmi),
  .nf_out(nf_hdmi),
  .ad_out(active_draw_hdmi),
  .fc_out(frame_count_hdmi)
  );

  test_pattern_generator pattern(.hcount_in(hcount_hdmi), .vcount_in(vcount_hdmi), .red_out(red), .green_out(green), .blue_out(blue));
 

  //  HDMI Output  //
  logic [9:0] tmds_10b    [0:2]; 
  logic       tmds_signal [2:0]; 

  tmds_encoder                           tmds_red(.clk_in(clk_pixel), .rst_in(rst_in), .data_in(red),
                                 .control_in(2'b0), .ve_in(active_draw_hdmi), .tmds_out(tmds_10b[2]));
  tmds_encoder                       tmds_green(.clk_in(clk_pixel), .rst_in(rst_in), .data_in(green),
                                 .control_in(2'b0), .ve_in(active_draw_hdmi), .tmds_out(tmds_10b[1]));
  tmds_encoder tmds_blue(                         .clk_in(clk_pixel),.rst_in(rst_in), .data_in(blue), 
  .control_in({vsync_hdmi,hsync_hdmi}), .ve_in(active_draw_hdmi), .tmds_out(tmds_10b[0]));

  tmds_serializer red_ser(    .clk_pixel_in(clk_pixel), .clk_5x_in(clk_5x),
  .rst_in(rst_in),.tmds_in(tmds_10b[2]), .tmds_out(tmds_signal[2]));
  tmds_serializer green_ser(   .clk_pixel_in(clk_pixel), .clk_5x_in(clk_5x), 
  .rst_in(rst_in), .tmds_in(tmds_10b[1]), .tmds_out(tmds_signal[1]));
  tmds_serializer blue_ser(    .clk_pixel_in(clk_pixel), .clk_5x_in(clk_5x), 
  .rst_in(rst_in), .tmds_in(tmds_10b[0]), .tmds_out(tmds_signal[0]));

  OBUFDS OBUFDS_blue (.I(tmds_signal[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
  OBUFDS OBUFDS_green(.I(tmds_signal[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
  OBUFDS OBUFDS_red  (.I(tmds_signal[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
  OBUFDS OBUFDS_clock(.I(clk_pixel), .O(hdmi_clk_p), .OB(hdmi_clk_n));

  // ---------------- //

endmodule