`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
    // System
    input wire clk_100mhz,
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

    //AZIMUTH/HRIR IO
    input wire [15:0]  sw
  );

  // Ground Truth.
  localparam AUDIO_WORD_WIDTH = 24;
  typedef enum logic {WAIT_SAMPLES = 1'b0, STREAMING = 1'b1} streaming_states; streaming_states streaming_state; 

  // System & High Level
  logic new_window;              // Beginning ~2200 cycle audio sample frame 
  logic last_cycle_window;       // Last cycle in ~2200 window
  logic last_cycle_bit;          // Within serial clock, last sysclk cycle, next sysclk cycle should have new bit 
  logic start;                   // Start ~2200 cycle processing

  logic sys_rst;                 // Reset entire pipeline
  assign sys_rst = btn[0];

  logic audio_bitrate_sck_clk;   // ~2.1168 MHz for bitrate
  logic   audio_sample_ws_clk;   // ~44.1 KHz clk for bounding audio samples

  assign sck_txd_clk = audio_bitrate_sck_clk;
  assign ws_txd_clk = audio_sample_ws_clk;

  //clock wizard module with sys_rxd_clk as output ...  44.1 kHz fs -> 11.2896 MHz
  audio_rate_clk_gen clk_gen (.clk_in(clk_100mhz), .rst_in(sys_rst), .clk_ws(audio_sample_ws_clk), .clk_sck(audio_bitrate_sck_clk), .new_window(new_window), .last_cycle(last_cycle_window), .last_cycle_bit(last_cycle_bit));
  
  // logic clk_11_298_MHz;
  // logic buffered_11_298_MHz;
  // assign sys_rxd_clk = buffered_11_298_MHz;

  clk_wiz_0 clk_gen_1 (.clk_in1(clk_100mhz), .clk_out1(sys_rxd_clk), .reset(sys_rst));
  // always_ff @(posedge clk_11_298_MHz) begin buffered_11_298_MHz <= ~buffered_11_298_MHz; end
  // always_ff @(negedge clk_11_298_MHz) begin buffered_11_298_MHz <= ~buffered_11_298_MHz; end

  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Module Interaction Below ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ //



  // *********************************** I2S RXD ******************************* //


  logic [AUDIO_WORD_WIDTH-1:0] data_rxd;
  logic channel_rxd;
  logic valid_rxd;

  logic fsync_rxd_buffer, sck_rxd_buffer, ws_rxd_buffer, sd_rxd_buffer;
  i2s_buffer   buffer   (.clk_in(clk_100mhz), .rst_in(sys_rst), .fsync_in(fsync_rxd), .sck_in(sck_rxd), .ws_in(ws_rxd), .sd_in(sd_rxd), .fsync_out(fsync_rxd_buffer), .sck_out(sck_rxd_buffer), .ws_out(ws_rxd_buffer), .sd_out(sd_rxd_buffer));
  i2s_receiver audio_in (.clk_in(clk_100mhz), .rst_in(sys_rst), .fsync(fsync_rxd_buffer), .sck(sck_rxd_buffer), .ws(ws_rxd_buffer), .sd(sd_rxd_buffer),  .data_out(data_rxd), .channel_out(channel_rxd), .valid_out(valid_rxd));    


  logic [AUDIO_WORD_WIDTH-1:0] data_final_left;
  logic [AUDIO_WORD_WIDTH-1:0] data_final_right;
  
  always_ff @(posedge clk_100mhz) begin
    if(valid_rxd) begin
      data_final_left  <= (channel_rxd)  ? data_rxd : data_final_left;
      data_final_right <= (!channel_rxd) ? data_rxd : data_final_right;
    end
  end

  // *************************************************************************** //

  // !!!!!  remove intermediatery in overlord !!!!!!! //
  
  // logic [AUDIO_WORD_WIDTH-1:0] left_out;
  // logic [AUDIO_WORD_WIDTH-1:0] right_out;

  // logic [AUDIO_WORD_WIDTH-1:0] tleft;
  // logic [AUDIO_WORD_WIDTH-1:0] tright;

  // assign tleft = 24'b0110111010101001110;
  // assign tright = 24'b0001111010101001110;

  // prop_buffer #(.STAGES_NEEDED(50), .DATA_WIDTH(24)) fifo_left (.clk_in(clk_100mhz), .data_in(data_rxd), .data_new(valid_rxd &&  channel_rxd),  .data_out(tleft));
  // prop_buffer #(.STAGES_NEEDED(50), .DATA_WIDTH(24)) fifo_right(.clk_in(clk_100mhz), .data_in(data_rxd), .data_new(valid_rxd && !channel_rxd), .data_out(tright));
  // !!                                            !! //



  // *********************************** I2S TXD ******************************* //

  i2s_transmitter audio_out(.clk_in(clk_100mhz), .rst_in(sys_rst), .data_left(data_final_left), 
  .data_right(data_final_right), .data_valid(1), .on_last_cycle(last_cycle_window), .on_last_cycle_bit(last_cycle_bit),
  .sclk(audio_bitrate_sck_clk), .ws(audio_sample_ws_clk), .sd(sd_txd));

  // *************************************************************************** //

endmodule // top_level
`default_nettype wire






































  // // ****************************** I/O Audio Sample BRAM ************************** //
  
  // //   State Logic and Parameters  
  // localparam BRAM_DEPTH = 512;                // number of samples buffered
  // localparam ADDR_WIDTH = $clog2(BRAM_DEPTH); // address width
  // localparam NUM_SAMPLES = 200;
  // logic [ADDR_WIDTH-1: 0] write_read_buffer; // how far is write address ahead of read address


  // //   I2S RXD to BRAM Write   

  // logic [AUDIO_WORD_WIDTH-1:0] dina; // Current Write data from I2S recieve
  // logic                 valid_write; // only read right channel, when valid data
  // logic [ADDR_WIDTH-1:0]      addra; // Current Write address

  // assign dina = data_rxd;         
  // assign valid_write = valid_rxd && (channel_rxd == 1); 
  // evt_counter #(.MAX_COUNT(BRAM_DEPTH)) read_address_a (.clk_in(clk_100mhz), .rst_in(sys_rst), .evt_in(valid_write), .count_out(addra));


  // //   BRAM Read to FIR input   
  // logic [AUDIO_WORD_WIDTH-1:0]    doutb; 
  // logic [ADDR_WIDTH-1:0]          start_addrb, addrb; //start and current Read address
  // logic                      ready_read;

  // logic loop_flag;
  // assign ready_read = (write_read_buffer > 205) && loop_flag;


  // evt_counter #(.MAX_COUNT(BRAM_DEPTH)) write_address_b (.clk_in(clk_100mhz), .rst_in(sys_rst), .evt_in(ready_read), .count_out(start_addrb));

  // logic [$clog2(NUM_SAMPLES) - 1: 0] i;
  // always_ff @(posedge clk_100mhz) begin

  //   if (sys_rst) begin
  //     addrb <= start_addrb;
  //     i <= 0;
  //   end

  //   else begin
  //     if (i < NUM_SAMPLES - 1) begin
  //       i <= i + 1;
  //       addrb <= start_addrb + i;
  //     end
  //     else begin 
  //       i <= 0;
  //       addrb <= start_addrb;
  //     end

  //   end
  // end


  // //  BRAM  
  // xilinx_true_dual_port_read_first_2_clock_ram #(.RAM_WIDTH(AUDIO_WORD_WIDTH), .RAM_DEPTH(BRAM_DEPTH)) audio_samples_bram(
  // .addra(addra), .dina(dina), .clka(clk_100mhz),
  // .wea(1'b1), .ena(valid_write), .rsta(sys_rst),
  // .regcea(1'b1), .douta(),
  // .addrb(addrb), .dinb(0), .clkb(clk_100mhz),
  // .web(1'b0), .enb(ready_read), .rstb(sys_rst),
  // .regceb(1'b1), .doutb(doutb));

  // //  Control Start Process Logic  
  // typedef enum logic [1:0] {NONE = 2'b00, INCREASE = 2'b01, DECREASE = 2'b10, INVALID = 2'b11} delta; delta net_buffer; 
  // assign net_buffer <= (!(valid_write ^ ready_read)) ? NONE : ((valid_write) ? INCREASE : DECREASE);  // Net change in write_read_buffer
  // assign start = (streaming_state == STREAMING) && (new_window);

  // always_ff @(posedge clk_100mhz) begin
  //   if(sys_rst) begin
  //     streaming_state <= WAIT_SAMPLES;
  //     write_read_buffer <= 0;
  //   end

  //   else begin
  //     streaming_state <= (write_read_buffer >= 200 && new_window) ? STREAMING : streaming_state;

  //     case (net_buffer)
  //     INCREASE: begin write_read_buffer <= write_read_buffer + 1; end
  //     DECREASE: begin write_read_buffer <= write_read_buffer - 1; end
  //     endcase

  //     if (start && ready_read) addrb <= addrb;
      
  //   end 
  // end

  // // *************************************************************************** //  


  
  // // ****************************** HRIR Coefficent BRAM ********************** //
  // logic [$clog2(TOTAL_NUM_COEFFS) + 1:0] start_hrir_coeff_addr, hrir_coeff_addr;
  // logic [31:0] hrir_ram_data_out;
  // logic hrir_ready_read, hrir_loop_flag;

  // assign start_hrir_coeff_addr = NUM_SAMPLES * azimuth;

  // logic [$clog2(NUM_SAMPLES) - 1: 0] j;
  // always_ff @(posedge clk_100mhz) begin

  //   if (sys_rst) begin
  //     hrir_coeff_addr <= start_hrir_coeff_addr;
  //     j <= 0;
  //   end
    
  //   else begin
  //     if (j < NUM_SAMPLES - 1) begin
  //       j <= j + 1;
  //       hrir_coeff_addr <= start_hrir_coeff_addr + j;
  //     end
  //     else begin 
  //       j <= 0;
  //       hrir_coeff_addr <= start_hrir_coeff_addr;
  //     end

  //   end
  // end
  

  // xilinx_single_port_ram_read_first #(
  //     .RAM_WIDTH(32),                              // Specify RAM data width for HRIR coefficients
  //     .RAM_DEPTH(5000),                            // Specify RAM depth (number of entries) 25 * 200
  //     .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
  //     .INIT_FILE(`FPATH(hrir_l_bs30_azi_full.mem)) //all azimuths with same bram, should just have pointer                  
  // ) 

  // hrir_coeff_brom (
  //   .addra(hrir_coeff_addr), .dina(0), 
  //   .clka(clk_100mhz), .wea(0), .ena(hrir_ready_read), 
  //   .rsta(rst_in), .regcea(1), .douta(hrir_ram_data_out)         
  // );


  

  // // *************************************************************************** //



  // // ***************************** FIR FILTER ********************************** //
    
  //   localparam NUM_AZIMUTHS = 25;
  //   localparam FIR_OUT_WIDTH = 64;
  //   localparam TOTAL_NUM_COEFFS = NUM_AZIMUTHS * 200;

  //   logic signed [4:0] azimuth;
  //   logic ws_in, fir_busy, ws_out, fir_valid_out;
  //   logic [FIR_OUT_WIDTH - 1: 0] fir_out;
  //   logic [AUDIO_WORD_WIDTH-1:0]    audio_sample_buffer; 

  //   logic [AUDIO_WORD_WIDTH - 1:0] left_out;
  //   logic [AUDIO_WORD_WIDTH - 1:0] right_out;

  //   logic db_btn_out1, db_btn_out2;

  //   debouncer btn1_db(
  //     .clk_in(clk_100mhz),
  //     .rst_in(sys_rst),
  //     .dirty_in(btn[1]),
  //     .clean_out(db_btn_out1)); //right button

  //   debouncer btn2_db(
  //     .clk_in(clk_100mhz),
  //     .rst_in(sys_rst),
  //     .dirty_in(btn[2]),
  //     .clean_out(db_btn_out2)); //left button

  //   always_ff @(posedge clk_100mhz) begin
  //     if (sys_rst) begin 
  //       azimuth <= 0;
  //     end else begin
  //       if (db_btn_out2) begin
  //         if (azimuth == 0) azimuth <= NUM_AZIMUTHS - 1;
  //         else azimuth <= azimuth + (-1);
  //       end else if (db_btn_out1) begin
  //         if (azimuth == NUM_AZIMUTHS - 1) azimuth <= 0;
  //         else azimuth <= azimuth + 1;
  //       end

  //     end
  //   end


  //   always_ff @(posedge clk_100mhz) begin
  //     if (sys_rst) ws <= 0;
  //     else if (fir_valid_out) begin 
  //       ws <= ~ws;
  //       if (!ws_out) left_out <= fir_out[28:3]; //most info
  //       else right_out <= fir_out[28:3];
  //     end
  //   end

  //   fir_filter #(
  //     .HRIR_COEFF_BIT_WIDTH(32);
  //     .AUDIO_WORD_WIDTH(AUDIO_WORD_WIDTH),
  //     .NUM_AZIMUTHS(NUM_AZIMUTHS),
  //     .NUM_LOAD_MULT_TERMS(8),
  //     .FIR_OUTPUT_BIT_WIDTH(FIR_OUT_WIDTH),
  //     .NUM_TOTAL_TERMS(200),
  // ) ( 
  //     .clk_in(clk_100mhz),
  //     .rst_in(sys_rst),   
  //     .start(start),                 // falling edge of SCK 
  //     .audio_sample_in(doutb),       //signed [AUDIO_WORD_WIDTH - 1: 0]
  //     .coeff_in(hrir_ram_data_out),  //signed [HRIR_COEFF_BIT_WIDTH - 1: 0] 
  //     .ws_in(ws_in),                 // left (0) or right (1) channel based on 
  //     .azimuth_in(azimuth),          //[$clog2(NUM_AZIMUTHS) - 1: 0] 
  //     .fir_busy(fir_busy),           //if low, in mult_stage
  //     .ws_out(ws_out),               //out
  //     .fir_valid_out(fir_valid_out), //out
  //     .audio_sample_out(audio_sample_buffer),   //[NUM_TOTAL_TERMS - 1: 0] [AUDIO_WORD_WIDTH - 1: 0] 
  //     .fir_out(fir_out)                         //[FIR_OUTPUT_BIT_WIDTH - 1: 0] 
  // );

  // // *************************************************************************** //
    
  