// `default_nettype none
module video_sig_gen
#(
  parameter ACTIVE_H_PIXELS = 1280,
  parameter H_FRONT_PORCH = 110,
  parameter H_SYNC_WIDTH = 40,
  parameter H_BACK_PORCH = 220,
  parameter ACTIVE_LINES = 720,
  parameter V_FRONT_PORCH = 5,
  parameter V_SYNC_WIDTH = 5,
  parameter V_BACK_PORCH = 20,
  parameter FPS = 60)
(
  input wire pixel_clk_in,
  input wire rst_in,
  output logic [$clog2(TOTAL_PIXELS)-1:0] hcount_out,
  output logic [$clog2(TOTAL_LINES)-1:0] vcount_out,
  output logic vs_out, // COMB vertical sync out
  output logic hs_out, // COMB horizontal sync out
  output logic ad_out, // COMB
  output logic nf_out, // COMB single cycle enable signal
  output logic [5:0] fc_out); //frame

  // parameters 
  localparam TOTAL_LINES = ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH + V_BACK_PORCH; 
  localparam TOTAL_PIXELS = ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH + H_BACK_PORCH;

  // Internal Logic
  logic [5:0]                       fcount;

  // Internal State Registers
  logic [$clog2(TOTAL_PIXELS)-1:0]  hcount;
  logic [$clog2(TOTAL_LINES)-1:0]   vcount;
  logic [5:0] previousfc;

  assign hcount_out = hcount;
  assign vcount_out = vcount;
  assign fc_out = fcount;

  // Combinational Logic
  always_comb begin
    ad_out = (vcount < ACTIVE_LINES && hcount < ACTIVE_H_PIXELS) ? 1 : 0;
    vs_out = (ACTIVE_LINES + V_FRONT_PORCH <= vcount && vcount < ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH) ? 1 : 0;
    hs_out = (ACTIVE_H_PIXELS + H_FRONT_PORCH <= hcount && hcount < ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH) ? 1 : 0;
    fcount = (hcount != ACTIVE_H_PIXELS || vcount != ACTIVE_LINES) ? previousfc : (previousfc == FPS - 1) ? 0 : previousfc + 1;
    nf_out = (hcount == ACTIVE_H_PIXELS && vcount == ACTIVE_LINES) ? 1 : 0;
  end 

  always_ff @(posedge pixel_clk_in ) begin
    if(rst_in) begin
      previousfc <= 0;
      hcount <= 0;
      vcount <= 0;
    end else begin
      previousfc <= fcount;
      if(hcount == TOTAL_PIXELS-1) begin
        hcount <= 0;
        vcount <= (vcount == TOTAL_LINES-1) ? 0 : vcount + 1;
      end else begin
        hcount <= hcount + 1;
      end
    end
  end

endmodule
// `default_nettype wire
