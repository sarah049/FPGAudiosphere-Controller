`timescale 1ns / 1ps
`default_nettype none


`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"../../hrir/X`"
`endif  /* ! SYNTHESIS */

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
    output logic sd_txd

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
  assign start = (streaming_state == STREAMING) && (new_window);

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



  // ************ Audio Sample BRAM State Logic and Parameters ***************** //

  localparam BRAM_DEPTH = 512;                // number of samples buffered
  localparam ADDR_WIDTH = $clog2(BRAM_DEPTH); // address width             
  localparam NUM_SAMPLES = 200;
  localparam NUM_AZIMUTHS = 25;
  
  // *************************************************************************** //



  // ********************** Writing to Audio Sample BRAM *********************** //

  logic [AUDIO_WORD_WIDTH-1:0] write_data; // Current Write data from I2S recieve
  logic                       valid_write; // only read right channel, when valid data
  logic [ADDR_WIDTH-1:0]    write_address; // Current Write address

  assign write_data = data_rxd;         
  assign valid_write = valid_rxd && (channel_rxd == 1); 

  // *************************************************************************** //



  // ************************** BRAM Address Bounds  *************************** //

  logic [ADDR_WIDTH-1:0]    write_read_buffer; // how far is write address ahead of read address
  logic [ADDR_WIDTH-1:0]  read_offset_address; // address of 200th most recent sample relative to FIR

  // Write Address Update
  evt_counter #(.MAX_COUNT(BRAM_DEPTH), .COUNT_WIDTH(ADDR_WIDTH)) write_address_update (.clk_in(clk_100mhz), .rst_in(sys_rst), .evt_in(valid_write), .count_out(write_address));

  // Read Offset Address Update
  logic update_read_offset_address; 

  // --- FYI this skips 1st sample that has enough samples for a valid output, also buffers faster txd i2s by repeating values if buffer drops too low
  assign update_read_offset_address = (last_cycle_window) && (streaming_state == STREAMING) && (write_read_buffer > 203); 

  evt_counter #(.MAX_COUNT(BRAM_DEPTH), .COUNT_WIDTH(ADDR_WIDTH)) read_offset_address_update (.clk_in(clk_100mhz), .rst_in(sys_rst), .evt_in(update_read_offset_address), .count_out(read_offset_address));


  // Update Buffer & Streaming
  typedef enum logic [1:0] {NONE = 2'b00, INCREASE = 2'b01, DECREASE = 2'b10, INVALID = 2'b11} delta; delta net_change_buffer; 
  assign net_change_buffer = (!(valid_write ^ update_read_offset_address)) ? NONE : ((valid_write) ? INCREASE : (update_read_offset_address) ? DECREASE : INVALID);  

  always_ff @(posedge clk_100mhz) begin

    if(sys_rst) begin
      streaming_state <= WAIT_SAMPLES;
      write_read_buffer <= 0;

    end else begin
      streaming_state <= (write_read_buffer >= 210 && new_window) ? STREAMING : streaming_state;
      case (net_change_buffer)
      INCREASE: begin write_read_buffer <= write_read_buffer + 1; end
      DECREASE: begin write_read_buffer <= (write_read_buffer == 0) ? 0 : write_read_buffer - 1; end
      endcase
    end 
  end

  // *************************************************************************** //  



  // ************************ Reading Audio Sample BRAM ************************ //

  //   BRAM Read to FIR input   
  logic [AUDIO_WORD_WIDTH-1:0] bram_read_out; 
  logic [AUDIO_WORD_WIDTH-1:0] current_read_out; 
  logic [ADDR_WIDTH-1:0]       current_read_address; //start address of 200 window, fir pointer address
  logic load_ready;
  logic [1:0 ]cycle_counter;

  always_ff @(posedge clk_100mhz) begin
    if(sys_rst) begin
      current_read_out <= 0;
      load_ready <= 0;
      cycle_counter <= 0;

    end else begin

        if(start) begin                     // |0 set read ready 
        cycle_counter <= 1;
        load_ready <= 1;
      end 
        else if (cycle_counter == 1) begin // |1 wait this cycle 
        cycle_counter <= 2;
      end 
        else if (cycle_counter == 2) begin // |2 register output this cycle and reset |
        cycle_counter <= 0;
        current_read_out <= bram_read_out;
      end

    end

  end 


  // *************************************************************************** //



  // ****************************** Audio Sample BRAM ************************** //
  
  xilinx_true_dual_port_read_first_2_clock_ram #(.RAM_WIDTH(AUDIO_WORD_WIDTH), .RAM_DEPTH(BRAM_DEPTH)) audio_samples_bram(
  //Writes
  .addra(write_address), .dina(write_data), .clka(clk_100mhz),
  .wea(1'b1), .ena(valid_write), .rsta(sys_rst),
  .regcea(1'b1), .douta(),
  // Reads
  .addrb(write_address - 205), .dinb(0), .clkb(clk_100mhz),
  .web(1'b0), .enb(load_ready), .rstb(sys_rst), //ready_read
  .regceb(1'b1), .doutb(bram_read_out));

  // *************************************************************************** //


  
  // *********************************** I2S TXD ******************************* //

  i2s_transmitter audio_out(.clk_in(clk_100mhz), .rst_in(sys_rst), .data_left(current_read_out), 
  .data_right(current_read_out), .data_valid(streaming_state), .on_last_cycle(last_cycle_window), .on_last_cycle_bit(last_cycle_bit),
  .sclk(audio_bitrate_sck_clk), .ws(audio_sample_ws_clk), .sd(sd_txd));

  // *************************************************************************** //


endmodule // top_level
`default_nettype wire

/* Switching data_right and 



*/








