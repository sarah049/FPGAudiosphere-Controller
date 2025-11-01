// `timescale 1ns / 1ps
// `default_nettype none


// `ifdef SYNTHESIS
// `define FPATH(X) `"X`"
// `else /* ! SYNTHESIS */
// `define FPATH(X) `"../../hrir/X`"
// `endif  /* ! SYNTHESIS */

// module top_level
//   (
//     // System
//     input wire clk_100mhz_sys,
//     input wire [3:0] btn,

//     // I2S IO
//     input wire fsync_rxd,
//     input wire sck_rxd,
//     input wire ws_rxd,
//     input wire sd_rxd,

//     output logic sys_rxd_clk,

//     output logic sck_txd_clk,
//     output logic ws_txd_clk,
//     output logic sd_txd,

//     // HDMI IO
//     output logic [2:0]  hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
//     output logic [2:0]  hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
//     output logic        hdmi_clk_p, hdmi_clk_n, //differential hdmi clock
//     output wire [15:0]   led,

//     //AZIMUTH/HRIR IO
//     input wire [15:0]   sw
//   );

//  // Ground Truth.
//   localparam AUDIO_WORD_WIDTH = 24;
//   typedef enum logic {WAIT_SAMPLES = 1'b0, STREAMING = 1'b1} streaming_states; streaming_states streaming_state; 
//   initial streaming_state = WAIT_SAMPLES;
  

//   //  Clock signals
//   logic clk_100mhz, clk_pixel, clk_5x;
//   cw_hdmi_clk_wiz wizard_hdmi(.sysclk(clk_100mhz), .clk_pixel(clk_pixel), .clk_tmds(clk_5x), .reset(0));
//   cw_fast_clk_wiz wizard_migcam(.clk_in1(clk_100mhz_sys), .clk_100(clk_100mhz), .reset(0));
  

//   // System & High Level
//   logic new_window;              // Beginning ~2200 cycle audio sample frame 
//   logic last_cycle_window;       // Last cycle in ~2200 window
//   logic last_cycle_bit;          // Within serial clock, last sysclk cycle, next sysclk cycle should have new bit 

//   logic start;                   // Start ~2200 cycle processing
//   assign start = (streaming_state == STREAMING) && (new_window);

//   logic sys_rst;                 // Reset entire pipeline
//   assign sys_rst = btn[0];

//   logic pixel_rst;
//   assign pixel_rst = btn[0];

//   logic audio_bitrate_sck_clk;   // ~2.1168 MHz for bitrate
//   logic   audio_sample_ws_clk;   // ~44.1 KHz clk for bounding audio samples

//   assign sck_txd_clk = audio_bitrate_sck_clk;
//   assign ws_txd_clk = audio_sample_ws_clk;

//   // clock generator module for ~44.1 kHz ws_txd and 2.198 MHz sck_txds
//   audio_rate_clk_gen clk_gen (.clk_in(clk_100mhz), .rst_in(sys_rst), .clk_ws(audio_sample_ws_clk), .clk_sck(audio_bitrate_sck_clk), .new_window(new_window), .last_cycle(last_cycle_window), .last_cycle_bit(last_cycle_bit));
  
//   //clock wizard module with sys_rxd_clk as output ...  44.1 kHz fs -> 11.2896 MHz
//   clk_wiz_0 clk_gen_1 (.clk_in1(clk_100mhz), .clk_out1(sys_rxd_clk), .reset(sys_rst));


//   // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Module Interaction Below ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ //



//   // *********************************** I2S RXD ******************************* //

//   logic [AUDIO_WORD_WIDTH-1:0] data_rxd;
//   logic channel_rxd;
//   logic valid_rxd;

//   logic fsync_rxd_buffer, sck_rxd_buffer, ws_rxd_buffer, sd_rxd_buffer;
//   i2s_buffer   buffer   (.clk_in(clk_100mhz), .rst_in(sys_rst), .fsync_in(fsync_rxd), .sck_in(sck_rxd), .ws_in(ws_rxd), .sd_in(sd_rxd), .fsync_out(fsync_rxd_buffer), .sck_out(sck_rxd_buffer), .ws_out(ws_rxd_buffer), .sd_out(sd_rxd_buffer));
//   i2s_receiver audio_in (.clk_in(clk_100mhz), .rst_in(sys_rst), .fsync(fsync_rxd_buffer), .sck(sck_rxd_buffer), .ws(ws_rxd_buffer), .sd(sd_rxd_buffer),  .data_out(data_rxd), .channel_out(channel_rxd), .valid_out(valid_rxd));    

//   // *************************************************************************** //



//   // ************ Audio Sample BRAM State Logic and Parameters ***************** //

//   localparam BRAM_DEPTH = 512;                // number of samples buffered
//   localparam ADDR_WIDTH = $clog2(BRAM_DEPTH); // address width
//   localparam NUM_SAMPLES = 200;
//   localparam NUM_AZIMUTHS = 25;
  
//   // *************************************************************************** //



//   // ********************** Writing to Audio Sample BRAM *********************** //

//   logic [AUDIO_WORD_WIDTH-1:0] write_data; // Current Write data from I2S recieve
//   logic                       valid_write; // only read right channel, when valid data
//   logic [ADDR_WIDTH-1:0]    write_address; // Current Write address

//   assign write_data = data_rxd;         
//   assign valid_write = valid_rxd && (channel_rxd == 1); 

//   // *************************************************************************** //



//   // ************************** BRAM Address Bounds  *************************** //

//   logic [ADDR_WIDTH-1: 0] write_read_buffer; // how far is write address ahead of read address
//   logic [ADDR_WIDTH-1:0]  read_offset_address; // address of 200th most recent sample relative to FIR

//   // Write Address Update
//   evt_counter #(.MAX_COUNT(BRAM_DEPTH), .COUNT_WIDTH(ADDR_WIDTH)) write_address_update (.clk_in(clk_100mhz), .rst_in(sys_rst), .evt_in(valid_write), .count_out(write_address));

//   // Read Offset Address Update
//   logic update_read_offset_address; 

//   // --- FYI this skips 1st sample that has enough samples for a valid output, also buffers faster txd i2s by repeating values if buffer drops too low
//   assign update_read_offset_address = (last_cycle_window) && (streaming_state == STREAMING) && (write_read_buffer > 203); 

//   evt_counter #(.MAX_COUNT(BRAM_DEPTH), .COUNT_WIDTH(ADDR_WIDTH)) read_offset_address_update (.clk_in(clk_100mhz), .rst_in(sys_rst), .evt_in(update_read_offset_address), .count_out(read_offset_address));


//   // Update Buffer & Streaming
//   typedef enum logic [1:0] {NONE = 2'b00, INCREASE = 2'b01, DECREASE = 2'b10, INVALID = 2'b11} delta; delta net_change_buffer; 
//   assign net_change_buffer = (!(valid_write ^ update_read_offset_address)) ? NONE : ((valid_write) ? INCREASE : (update_read_offset_address) ? DECREASE : INVALID);  

//   always_ff @(posedge clk_100mhz) begin

//     if(sys_rst) begin
//       streaming_state <= WAIT_SAMPLES;
//       write_read_buffer <= 0;

//     end else begin
//       streaming_state <= (write_read_buffer >= 210 && new_window) ? STREAMING : streaming_state;
//       case (net_change_buffer)
//       INCREASE: begin write_read_buffer <= write_read_buffer + 1; end
//       DECREASE: begin write_read_buffer <= write_read_buffer - 1; end
//       endcase
//     end 
//   end

//   // *************************************************************************** //  



//   // ************************ Reading Audio Sample BRAM ************************ //

//   //   BRAM Read to FIR input   
//   logic [AUDIO_WORD_WIDTH-1:0] bram_read_out; 
//   logic [ADDR_WIDTH-1:0]       current_read_address; //start address of 200 window, fir pointer address
//   logic                        ready_read;
//   logic mid_wave_switch;

//   logic[ADDR_WIDTH + $clog2(NUM_SAMPLES) - 1: 0] current_read_address_max;
//   assign current_read_address_max = read_offset_address + 200;

//   always_ff @(posedge clk_100mhz) begin

//     if (sys_rst) begin
//       current_read_address <= 0;
//       // audio_bram_wait <= 1;
//     end else begin
//       if (start || mid_wave_switch) current_read_address <= read_offset_address;
//       else if (ready_read) begin
//         if (current_read_address < current_read_address_max - 1) current_read_address <= current_read_address + 1;
//         else current_read_address <= read_offset_address;
//     end
//     end
//   end

//   //TODO: 
// //implement current_read_address logic
// //swtich from left to right computation within one wave
//   // *************************************************************************** //



//   // ****************************** Audio Sample BRAM ************************** //
  
//   xilinx_true_dual_port_read_first_2_clock_ram #(.RAM_WIDTH(AUDIO_WORD_WIDTH), .RAM_DEPTH(BRAM_DEPTH)) audio_samples_bram(
//   //Writes
//   .addra(write_address), .dina(write_data), .clka(clk_100mhz),
//   .wea(1'b1), .ena(valid_write), .rsta(sys_rst),
//   .regcea(1'b1), .douta(),
//   // Reads
//   .addrb(current_read_address), .dinb(0), .clkb(clk_100mhz),
//   .web(1'b0), .enb(ready_read), .rstb(sys_rst),
//   .regceb(1'b1), .doutb(bram_read_out));

//   // *************************************************************************** //


  
//   // ****************************** HRIR Coefficent BRAM ********************** //
//   localparam HRIR_COEFF_BIT_WIDTH = 32;
//   localparam TOTAL_NUM_COEFFS = NUM_AZIMUTHS * 200;
  

//   logic [$clog2(TOTAL_NUM_COEFFS) - 1:0] hrir_offset_address, current_hrir_address;
//   logic [HRIR_COEFF_BIT_WIDTH - 1:0] hrir_left_ram_data_out;
//   logic [HRIR_COEFF_BIT_WIDTH - 1:0] hrir_right_ram_data_out;
//   logic [HRIR_COEFF_BIT_WIDTH - 1:0] hrir_ram_data_out_buffer;  
//   logic load_ready;
//   logic left_hrir_ready_read, right_hrir_ready_read;
//   logic ws_in, fir_valid_out;
  
//   logic signed [$clog2(NUM_AZIMUTHS) :0] azimuth;

// //generate own "ws_in" signal to properly read from hrir brams and feed into fir filter 
//   always_ff @(posedge clk_100mhz) begin
//       if (sys_rst) ws_in <= 0;
//       else if (fir_valid_out) begin //at the end of each wave, flip the ws_in signal
//         ws_in <= ~ws_in;

//       end
//   end

//   assign hrir_offset_address = NUM_SAMPLES * azimuth;
//   assign left_hrir_ready_read = load_ready & ~ws_in; //should be ws_in or mid_wave_switch?
//   assign right_hrir_ready_read = load_ready & ws_in;

//   assign hrir_ram_data_out_buffer = (~ws_in ? hrir_left_ram_data_out: hrir_right_ram_data_out);

//   logic [$clog2(TOTAL_NUM_COEFFS) - 1: 0] current_hrir_address_max;
//   assign current_hrir_address_max = hrir_offset_address + 200;
  
//   //hrir address calculations
//   always_ff @(posedge clk_100mhz) begin

//     if (sys_rst) begin
//       current_hrir_address <= 0;
//     end
    
//     else begin
//       if (start || mid_wave_switch) current_hrir_address <= hrir_offset_address;
//       else if (ready_read) begin
//         if (current_hrir_address < current_hrir_address_max - 1) current_hrir_address <= current_hrir_address + 1;
//         else current_hrir_address <= hrir_offset_address;
//     end
//     end
//   end
  

//   xilinx_single_port_ram_read_first #(
//       .RAM_WIDTH(32),                              // Specify RAM data width for HRIR coefficients
//       .RAM_DEPTH(5000),                            // Specify RAM depth (number of entries) 25 * 200
//       .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
//       .INIT_FILE(`FPATH(hrir_l_bs30_azi_full.mem)) //all azimuths with same bram, should just have pointer                  
//   ) 
//   hrir_left_coeff_brom (
//     .addra(current_hrir_address), .dina(0), 
//     .clka(clk_100mhz), .wea(0), .ena(left_hrir_ready_read), 
//     .rsta(sys_rst), .regcea(1), .douta(hrir_left_ram_data_out)         
//   );


//   xilinx_single_port_ram_read_first #(
//       .RAM_WIDTH(32),                              // Specify RAM data width for HRIR coefficients
//       .RAM_DEPTH(5000),                            // Specify RAM depth (number of entries) 25 * 200
//       .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
//       .INIT_FILE(`FPATH(hrir_r_bs30_azi_full.mem)) //all azimuths with same bram, should just have pointer                  
//   ) 
//   hrir_right_coeff_brom (
//     .addra(current_hrir_address), .dina(0), 
//     .clka(clk_100mhz), .wea(0), .ena(right_hrir_ready_read), 
//     .rsta(sys_rst), .regcea(1), .douta(hrir_right_ram_data_out)         
//   );

//   // *************************************************************************** //



//   // ***************************** FIR FILTER ********************************** //
    
    
//     localparam FIR_OUT_WIDTH = 58;
    

    
//     logic fir_busy, ws_out;
//     logic [FIR_OUT_WIDTH - 1: 0] fir_out;
//     logic [AUDIO_WORD_WIDTH-1:0] audio_sample_buffer; 

//     logic [AUDIO_WORD_WIDTH - 1:0] left_out;
//     logic [AUDIO_WORD_WIDTH - 1:0] right_out;

//     logic db_btn_out1, db_btn_out2;

//     debouncer btn1_db(
//       .clk_in(clk_100mhz),
//       .rst_in(sys_rst),
//       .dirty_in(btn[1]),
//       .clean_out(db_btn_out1)); //right button

//     debouncer btn2_db(
//       .clk_in(clk_100mhz),
//       .rst_in(sys_rst),
//       .dirty_in(btn[2]),
//       .clean_out(db_btn_out2)); //left button

//     azimuth #(
//       .NUM_AZIMUTHS(NUM_AZIMUTHS)
//     ) azi_control (
//     .clk_in(clk_100mhz),
//     .rst_in(sys_rst),
//     .left_btn(db_btn_out2),
//     .right_btn(db_btn_out1),
//     .azimuth_out(azimuth));


//     always_ff @(posedge clk_100mhz) begin
//       if (sys_rst) begin
//         left_out <= 0;
//         right_out <= 0;
//         mid_wave_switch <= 0;
//       end
//       else if (fir_valid_out) begin 

//         if (!ws_out) begin 
//           left_out <= fir_out[FIR_OUT_WIDTH - 1: FIR_OUT_WIDTH - 1 - AUDIO_WORD_WIDTH]; //top 24 bits = most info
//           mid_wave_switch <= 1;
//         end
//         else begin 
//           right_out <= fir_out[FIR_OUT_WIDTH - 1: FIR_OUT_WIDTH - 1 - AUDIO_WORD_WIDTH];
//           mid_wave_switch <= 0;
//         end

//       end
//     end

//     fir_filter #(
//       .HRIR_COEFF_BIT_WIDTH(HRIR_COEFF_BIT_WIDTH), //32
//       .AUDIO_WORD_WIDTH(AUDIO_WORD_WIDTH), //24
//       .NUM_LOAD_MULT_TERMS(8), //8
//       .FIR_OUTPUT_BIT_WIDTH(FIR_OUT_WIDTH), //58
//       .NUM_TOTAL_TERMS(NUM_SAMPLES) //200
//   ) fir ( 
//       .clk_in(clk_100mhz),
//       .rst_in(sys_rst),   
//       .start(start || mid_wave_switch),                 // falling edge of SCK 
//       .audio_sample_in(bram_read_out),       //signed [AUDIO_WORD_WIDTH - 1: 0]
//       .coeff_in(hrir_ram_data_out_buffer),  //signed [HRIR_COEFF_BIT_WIDTH - 1: 0] 
//       .ws_in(ws_in),                 // left (0) or right (1) channel
//       .load_ready(load_ready),
//       .fir_busy(fir_busy),           //if low, in mult_stage
//       .ws_out(ws_out),               //out
//       .fir_valid_out(fir_valid_out), //out
//       .audio_sample_out(audio_sample_buffer),   //[NUM_TOTAL_TERMS - 1: 0] [AUDIO_WORD_WIDTH - 1: 0] 
//       .fir_out(fir_out)                         //[FIR_OUTPUT_BIT_WIDTH - 1: 0] 
//   );

//   assign led = fir_out[15:0];

//   // *************************************************************************** //

    
  
//   // *********************************** I2S TXD ******************************* //

//   i2s_transmitter audio_out(.clk_in(clk_100mhz), .rst_in(sys_rst), .data_left(left_out), 
//   .data_right(right_out), .data_valid(streaming_state), .on_last_cycle(last_cycle_window), .on_last_cycle_bit(last_cycle_bit),
//   .sclk(audio_bitrate_sck_clk), .ws(audio_sample_ws_clk), .sd(sd_txd));

//   // *************************************************************************** //



//   // ***************************** Video Controller **************************** // 
  
//   video_controller video_control(                 //         !!!!! TIME DOMAIN CROSSING !!!!!          //
//   .clk_100mhz(clk_100mhz), .clk_pixel(clk_pixel), .clk_5x(clk_5x), .rst_in(pixel_rst),                 // System
//   .last_cycle_audio(last_cycle_window), .data_valid(streaming_state),                                  // Control
//   .og_data(audio_sample_buffer), .left_data(left_out), .right_data(right_out),                                    // Data
//   .hdmi_tx_p(hdmi_tx_p), .hdmi_tx_n(hdmi_tx_n), .hdmi_clk_p(hdmi_clk_p), .hdmi_clk_n(hdmi_clk_n));     // HDMI

//   // *************************************************************************** //

 

// endmodule // top_level
// `default_nettype wire









