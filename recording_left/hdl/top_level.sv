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
    output logic sd_txd,

    // HDMI IO
    output logic [2:0]  hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
    output logic [2:0]  hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
    output logic        hdmi_clk_p, hdmi_clk_n, //differential hdmi clock
    output logic [15:0]   led,

    //AZIMUTH/HRIR IO
    input wire [15:0]   sw
  );

 // Ground Truth.
  localparam AUDIO_WORD_WIDTH = 24;

  

  //  Clock signals
  logic clk_100mhz, clk_pixel, clk_5x;
  cw_hdmi_clk_wiz wizard_hdmi(.sysclk(clk_100mhz), .clk_pixel(clk_pixel), .clk_tmds(clk_5x), .reset(0));
  cw_fast_clk_wiz wizard_migcam(.clk_in1(clk_100mhz_sys), .clk_100(clk_100mhz), .reset(0));
  

  // System & High Level
  logic new_window;              // Beginning ~2200 cycle audio sample frame 
  logic last_cycle_window;       // Last cycle in ~2200 window
  logic last_cycle_bit;          // Within serial clock, last sysclk cycle, next sysclk cycle should have new bit 

  logic start;                   // Start ~2200 cycle processing
  assign start = new_window;

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
  assign valid_write = valid_rxd && (channel_rxd == 0); 

  evt_counter #(.MAX_COUNT(BRAM_DEPTH), .COUNT_WIDTH(AUDIO_WORD_WIDTH)) write_addr_counter (.clk_in(clk_100mhz), .rst_in(sys_rst), .evt_in(valid_write), .count_out(write_address));

  // *************************************************************************** //



  // ************************** BRAM Address Bounds  *************************** //

  logic [ADDR_WIDTH-1:0]  read_offset_address; // address of 200th most recent sample relative to FIR

  always_ff @(posedge clk_100mhz) begin
    if (sys_rst) begin 
      read_offset_address <= 0;
    end
    else if (new_window) begin
      read_offset_address <= write_address - 205;
    end 
  end


  // *************************************************************************** //  



  // ************************ Reading Audio Sample BRAM ************************ //

  //   BRAM Read to FIR input   
  logic [AUDIO_WORD_WIDTH-1:0] bram_read_out; 
  logic [ADDR_WIDTH-1:0]       current_read_address; //start address of 200 window, fir pointer address
  logic load_ready, left_load_ready, right_load_ready;

  always_ff @(posedge clk_100mhz) begin
    if (sys_rst) current_read_address <= 0;
    else if (start) begin  //set_read_address
      current_read_address <= read_offset_address;
    end
    else if (load_ready) current_read_address <= current_read_address + 1;
  end

  assign load_ready = left_load_ready || right_load_ready;

  //TODO: 
//implement current_read_address logic
//swtich from left to right computation within one wave
  // *************************************************************************** //



  // ****************************** Audio Sample BRAM ************************** //
  
  xilinx_true_dual_port_read_first_2_clock_ram #(.RAM_WIDTH(AUDIO_WORD_WIDTH), .RAM_DEPTH(BRAM_DEPTH)) audio_samples_bram(
  //Writes
  .addra(write_address), .dina(write_data), .clka(clk_100mhz),
  .wea(valid_write), .ena(1'b1), .rsta(sys_rst),
  .regcea(1'b1), .douta(),
  // Reads
  .addrb(current_read_address), .dinb(0), .clkb(clk_100mhz),
  .web(1'b0), .enb(1'b1), .rstb(sys_rst), //ready_read
  .regceb(1'b1), .doutb(bram_read_out));

  // *************************************************************************** //

// ***************************** AZIMUTH LOGIC ********************************** //

    // logic [$clog2(NUM_AZIMUTHS)-1:0] azimuth_out;
    //   assign led = azimuth_out;

    //   always_ff @(posedge clk_100mhz) begin
    //     if (sys_rst) begin 
    //       azimuth_out <= 0;
    //     end else begin
    //       if (sw < NUM_AZIMUTHS) azimuth_out <= sw;
    //       else azimuth_out <= NUM_AZIMUTHS - 1;
    //     end
    //   end

    logic [$clog2(NUM_AZIMUTHS)-1:0] azimuth_out;
      assign led = azimuth_out;
      logic right_btn, left_btn;
    localparam AZIMUTH_WINDOW = 11363; //half a second
    logic [$clog2(AZIMUTH_WINDOW) - 1: 0] azi_window_count;

    //   debouncer btn1_db(
    //   .clk_in(clk_100mhz),
    //   .rst_in(sys_rst),
    //   .dirty_in(btn[1]),
    //   .clean_out(right_btn)); //right button

    // debouncer btn2_db(
    //   .clk_in(clk_100mhz),
    //   .rst_in(sys_rst),
    //   .dirty_in(btn[2]),
    //   .clean_out(left_btn)); //left button

       always_ff @(posedge clk_100mhz) begin
        if (sys_rst) begin 
          azimuth_out <= 0;
          azi_window_count <= 0;
        end else if (sw[15] & start) begin //if last switch is on, autosweep azimuth
  
            if (azi_window_count < AZIMUTH_WINDOW - 1) azi_window_count <= azi_window_count + 1;
            else if (azi_window_count == AZIMUTH_WINDOW - 1) begin
                if (azimuth_out == NUM_AZIMUTHS - 1) azimuth_out <= 0;
                else azimuth_out <= azimuth_out + 1;
                azi_window_count <= 0;
            end
        end else if (~sw[15]) begin
          if (sw[4:0] < NUM_AZIMUTHS) azimuth_out <= sw[4:0];
          else azimuth_out <= NUM_AZIMUTHS - 1;
          //  if (left_btn) begin //else control with buttons
          //     if (azimuth_out == 0) azimuth_out <= NUM_AZIMUTHS - 1;
          //     else azimuth_out <= azimuth_out - 1;
          // end else if (right_btn) begin
          //   if (azimuth_out == NUM_AZIMUTHS - 1) azimuth_out <= 0;
          //   else azimuth_out <= azimuth_out + 1;
          // end
        end
      end

    // *************************************************************************** //
  
  // ****************************** HRIR Coefficent BRAM ********************** //
  localparam HRIR_COEFF_BIT_WIDTH = 32;
  localparam TOTAL_NUM_COEFFS = NUM_AZIMUTHS * 200;
  

  logic [$clog2(TOTAL_NUM_COEFFS) - 1:0] hrir_offset_address, current_hrir_address;
  logic [HRIR_COEFF_BIT_WIDTH - 1:0] hrir_left_ram_data_out;
  logic [HRIR_COEFF_BIT_WIDTH - 1:0] hrir_right_ram_data_out;
  logic [HRIR_COEFF_BIT_WIDTH - 1:0] hrir_ram_data_out_buffer;  
  
  logic left_hrir_ready_read, right_hrir_ready_read;
  logic ws_in, fir_valid_out;

  logic left_fir_valid_out, right_fir_valid_out;

  assign fir_valid_out = left_fir_valid_out || right_fir_valid_out;

//generate own "ws_in" signal to properly read from hrir brams and feed into fir filter 
  always_ff @(posedge clk_100mhz) begin
      if (sys_rst || start ) ws_in <= 0; //start from left
      else if (fir_valid_out) begin //at the end of each wave, flip the ws_in signal
        ws_in <= ~ws_in;

      end
  end

  assign hrir_offset_address = NUM_SAMPLES * azimuth_out;
  assign left_hrir_ready_read = load_ready & ~ws_in; //should be ws_in because full fir cycle
  assign right_hrir_ready_read = load_ready & ws_in;

  
  //hrir address calculations
  always_ff @(posedge clk_100mhz) begin

    if (sys_rst) begin
      current_hrir_address <= 0; 
    end
    
    else begin
      if (start ) current_hrir_address <= hrir_offset_address;
      else if (load_ready) begin
        current_hrir_address <= current_hrir_address + 1; // +1
    end
    end
  end
  

  xilinx_single_port_ram_read_first #(
      .RAM_WIDTH(32),                              // Specify RAM data width for HRIR coefficients
      .RAM_DEPTH(5000),                            // Specify RAM depth (number of entries) 25 * 200
      .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
      .INIT_FILE(`FPATH(hrir_l_bs30_azi_full.mem)) //all azimuths with same bram, should just have pointer                  
  ) 
  hrir_left_coeff_brom (
    .addra(current_hrir_address), .dina(0), 
    .clka(clk_100mhz), .wea(0), .ena(1'b1),  //left_hrir_ready_read
    .rsta(sys_rst), .regcea(1), .douta(hrir_left_ram_data_out)         
  );


  xilinx_single_port_ram_read_first #(
      .RAM_WIDTH(32),                              // Specify RAM data width for HRIR coefficients
      .RAM_DEPTH(5000),                            // Specify RAM depth (number of entries) 25 * 200
      .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
      .INIT_FILE(`FPATH(hrir_r_bs30_azi_full.mem)) //all azimuths with same bram, should just have pointer                  
  ) 
  hrir_right_coeff_brom (
    .addra(current_hrir_address), .dina(0), 
    .clka(clk_100mhz), .wea(0), .ena(1'b1), //right_hrir_ready_read 
    .rsta(sys_rst), .regcea(1), .douta(hrir_right_ram_data_out)         
  );

  // *************************************************************************** //


  // ***************************** FIR FILTER ********************************** //
    
    
    localparam FIR_OUT_WIDTH = 58;
    
    logic fir_busy, ws_out;
    logic left_fir_busy, right_fir_busy;
    logic [FIR_OUT_WIDTH - 1: 0] left_fir_out, right_fir_out;

    logic [AUDIO_WORD_WIDTH-1:0] audio_sample_buffer;
    logic [AUDIO_WORD_WIDTH-1:0] left_audio_sample_buffer, right_audio_sample_buffer; 
 

    logic [AUDIO_WORD_WIDTH - 1:0] left_out;
    logic [AUDIO_WORD_WIDTH - 1:0] right_out;
    localparam FIR_OUT_IX_OFFSET = 0;


    always_ff @(posedge clk_100mhz) begin
      if (sys_rst) begin
        left_out <= 0;
        right_out <= 0;
      end else begin

        if (fir_valid_out) begin
            left_out <= {left_fir_out[FIR_OUT_WIDTH - 1], left_fir_out[FIR_OUT_WIDTH - 1 - FIR_OUT_IX_OFFSET: FIR_OUT_WIDTH - 1 - FIR_OUT_IX_OFFSET - AUDIO_WORD_WIDTH]}; //top 24 bits = most info
            right_out <= {right_fir_out[FIR_OUT_WIDTH - 1], right_fir_out[FIR_OUT_WIDTH - 1 - FIR_OUT_IX_OFFSET: FIR_OUT_WIDTH - 1 - FIR_OUT_IX_OFFSET - AUDIO_WORD_WIDTH]};
          end
          
      end

    end

    logic left_ws_out, right_ws_out;

  fir_filter #(
      .HRIR_COEFF_BIT_WIDTH(HRIR_COEFF_BIT_WIDTH), //32
      .AUDIO_WORD_WIDTH(AUDIO_WORD_WIDTH), //24
      .NUM_LOAD_MULT_TERMS(8), //8
      .FIR_OUTPUT_BIT_WIDTH(FIR_OUT_WIDTH), //58
      .NUM_TOTAL_TERMS(NUM_SAMPLES) //200
    ) left_fir ( 
      .clk_in(clk_100mhz),
      .rst_in(sys_rst),   
      .start(start),                 // falling edge of SCK 
      .audio_sample_in(bram_read_out),       //signed [AUDIO_WORD_WIDTH - 1: 0]
      .coeff_in(hrir_left_ram_data_out),  //signed [HRIR_COEFF_BIT_WIDTH - 1: 0] 
      .ws_in(ws_in),                 // left (0) or right (1) channel
      .load_ready(left_load_ready),
      .fir_busy(left_fir_busy),           //if low, in mult_stage
      .ws_out(left_ws_out),               //out
      .fir_valid_out(left_fir_valid_out), //out
      .audio_sample_out(left_audio_sample_buffer),   //[NUM_TOTAL_TERMS - 1: 0] [AUDIO_WORD_WIDTH - 1: 0] 
      .fir_out(left_fir_out)                         //[FIR_OUTPUT_BIT_WIDTH - 1: 0] 
  );

  fir_filter #(
      .HRIR_COEFF_BIT_WIDTH(HRIR_COEFF_BIT_WIDTH), //32
      .AUDIO_WORD_WIDTH(AUDIO_WORD_WIDTH), //24
      .NUM_LOAD_MULT_TERMS(8), //8
      .FIR_OUTPUT_BIT_WIDTH(FIR_OUT_WIDTH), //58
      .NUM_TOTAL_TERMS(NUM_SAMPLES) //200
  ) right_fir ( 
      .clk_in(clk_100mhz),
      .rst_in(sys_rst),   
      .start(start),                 // falling edge of SCK 
      .audio_sample_in(bram_read_out),       //signed [AUDIO_WORD_WIDTH - 1: 0]
      .coeff_in(hrir_right_ram_data_out),  //signed [HRIR_COEFF_BIT_WIDTH - 1: 0] 
      .ws_in(ws_in),                 // left (0) or right (1) channel
      .load_ready(right_load_ready),
      .fir_busy(right_fir_busy),           //if low, in mult_stage
      .ws_out(right_ws_out),               //out
      .fir_valid_out(right_fir_valid_out), //out
      .audio_sample_out(audio_sample_buffer),   //[NUM_TOTAL_TERMS - 1: 0] [AUDIO_WORD_WIDTH - 1: 0] 
      .fir_out(right_fir_out)                         //[FIR_OUTPUT_BIT_WIDTH - 1: 0] 
  );

  // *************************************************************************** //

    
  
  // *********************************** I2S TXD ******************************* //

  i2s_transmitter audio_out(.clk_in(clk_100mhz), .rst_in(sys_rst), .data_left(left_out), 
  .data_right(left_out), .data_valid(1), .on_last_cycle(last_cycle_window), .on_last_cycle_bit(last_cycle_bit),
  .sclk(audio_bitrate_sck_clk), .ws(audio_sample_ws_clk), .sd(sd_txd));

  // *************************************************************************** //



  // ***************************** Video Controller **************************** // 
  
  video_controller video_control(                 //         !!!!! TIME DOMAIN CROSSING !!!!!          //
  .clk_100mhz(clk_100mhz), .clk_pixel(clk_pixel), .clk_5x(clk_5x), .rst_in(pixel_rst),  .rst_in_100mhz(sys_rst),              // System
  .last_cycle_audio(last_cycle_window), .data_valid(1),                                  // Control
  .og_data(audio_sample_buffer), .left_data(left_out), .right_data(right_out),                                    // Data
  .hdmi_tx_p(hdmi_tx_p), .hdmi_tx_n(hdmi_tx_n), .hdmi_clk_p(hdmi_clk_p), .hdmi_clk_n(hdmi_clk_n));     // HDMI

  // *************************************************************************** //

 

endmodule // top_level
`default_nettype wire









