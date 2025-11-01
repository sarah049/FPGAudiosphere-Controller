`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
    // System
    input wire clk_100mhz,

    // HDMI IO
    output logic [2:0]  hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
    output logic [2:0]  hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
    output logic        hdmi_clk_p, hdmi_clk_n //differential hdmi clock
  );

  
  
  // *************************** Video Controller ****************************** //
  video_controller video_control (
  .clk_in(clk_100mhz), .rst_in(0), .hdmi_tx_p(hdmi_tx_p), 
  .hdmi_tx_n(hdmi_tx_n), .hdmi_clk_p(hdmi_clk_p), .hdmi_clk_n(hdmi_clk_n)
  );
  // *************************************************************************** //

endmodule // top_level
`default_nettype wire





