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
    input wire clk_100mhz,
    input wire [1:0] btn,

     // HDMI IO
    // output logic [2:0]  hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
    // output logic [2:0]  hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
    // output logic        hdmi_clk_p, hdmi_clk_n, //differential hdmi clock

    // //AZIMUTH/HRIR IO
    output wire [15:0]   led
    //max 110 bits
    // 
    // output logic [31:0] hrir_left_ram_data_out,
    // output logic [31:0] hrir_right_ram_data_out
    // output logic [12:0] addrb
    
  );

  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Module Interaction Below ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ //

  // ****************************** I/O Audio Sample BRAM ************************** //
  
  //   State Logic and Parameters  
  localparam AUDIO_WORD_WIDTH = 24;
  
  localparam NUM_AZIMUTHS = 25;
  localparam FIR_OUT_WIDTH = 58;
  localparam TOTAL_NUM_COEFFS = NUM_AZIMUTHS * 200;

  localparam BRAM_DEPTH = 210;                // number of samples buffered 210
  localparam ADDR_WIDTH = $clog2(BRAM_DEPTH); // address width
  localparam NUM_SAMPLES = 200;

  logic [23:0] doutb;
  logic signed [FIR_OUT_WIDTH - 1:0] fir_out;
  //   BRAM Read to FIR input   
  // logic [AUDIO_WORD_WIDTH-1:0]    doutb; 
  logic [ADDR_WIDTH-1:0]          start_addrb, addrb; //start and current Read address
  logic                      ready_read;
  logic audio_bram_wait;

  logic          sys_rst;

  assign ready_read = 1 ;//&& hrir_ready_read - hardcoded
  assign sys_rst = btn[0];

  // evt_counter #(.MAX_COUNT(BRAM_DEPTH), .COUNT_WIDTH(ADDR_WIDTH)) read_address_b (.clk_in(clk_in), .rst_in(sys_rst), .evt_in(ready_read), .count_out(start_addrb));

  logic [$clog2(NUM_SAMPLES) - 1: 0] i;
  always_ff @(posedge clk_100mhz) begin

    if (sys_rst) begin
      start_addrb <= 0;
      addrb <= 0; 
      audio_bram_wait <= 1;
      i <= 0;
    end

    else if (ready_read) begin //when ready to load from bram
      if (i < NUM_SAMPLES - 1) begin
        i <= i + 1;
        addrb <= start_addrb + i;
      end
      else begin 
        i <= 0;
        addrb <= start_addrb;
      end

    end
  end


  //  BRAM  
  xilinx_single_port_ram_read_first #(
      .RAM_WIDTH(AUDIO_WORD_WIDTH),                              // Specify RAM data width for HRIR coefficients
      .RAM_DEPTH(210),                            // Specify RAM depth (number of entries) 25 * 200
      .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
      .INIT_FILE(`FPATH(test_audio_unsigned_210.mem)) //all azimuths with same bram, should just have pointer                  
  ) 
  audio_samples_bram (
    .addra(addrb), .dina(), .clka(clk_100mhz),
  .wea(1'b0), .ena(ready_read), .rsta(sys_rst),
  .regcea(1'b1), .douta(doutb)        
  );

    // *************************************************************************** //



  // ****************************** HRIR Coefficent BRAM ********************** //
  logic [$clog2(TOTAL_NUM_COEFFS) - 1:0] start_hrir_coeff_addr, hrir_coeff_addr;
  logic [31:0] hrir_left_ram_data_out, hrir_left_ram_data_out_buffer;
  logic [31:0] hrir_right_ram_data_out, hrir_right_ram_data_out_buffer;
  logic [31:0] hrir_ram_data_out_buffer;  
  logic hrir_ready_read;
  logic left_hrir_ready_read, right_hrir_ready_read;
  logic ws_in;
  logic [3:0] fir_state;

//generate own "ws_in" signal to properly read from hrir brams and feed into fir filter 
  always_ff @(posedge clk_100mhz) begin
      if (sys_rst) ws_in <= 0;
      else if (fir_valid_out) begin //should I just use ws_rxd_buffer signal?
        ws_in <= ~ws_in;
      end
  end

  assign start_hrir_coeff_addr = NUM_SAMPLES * azimuth;
  assign left_hrir_ready_read = hrir_ready_read & ~ws_in;
  assign right_hrir_ready_read = hrir_ready_read & ws_in;


  logic [$clog2(NUM_SAMPLES) - 1: 0] j;

  always_ff @(posedge clk_100mhz) begin

    if (sys_rst) begin
      hrir_coeff_addr <= start_hrir_coeff_addr;
      hrir_ram_data_out_buffer <= 0;
      j <= 0;
    end
    
    else begin
      
      if (j < NUM_SAMPLES - 1) begin
        j <= j + 1;
        hrir_coeff_addr <= start_hrir_coeff_addr + j;
      end
      else begin 
        j <= 0;
        hrir_coeff_addr <= start_hrir_coeff_addr;
      end

      hrir_ram_data_out_buffer <= (ws_in? hrir_right_ram_data_out: hrir_left_ram_data_out);
    end
  end
  

  xilinx_single_port_ram_read_first #(
      .RAM_WIDTH(32),                              // Specify RAM data width for HRIR coefficients
      .RAM_DEPTH(TOTAL_NUM_COEFFS),                            // Specify RAM depth (number of entries) 25 * 200
      .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
      .INIT_FILE(`FPATH(hrir_l_bs30_azi_full.mem)) //all azimuths with same bram, should just have pointer                  
  ) 
  hrir_left_coeff_brom (
    .addra(addrb), .dina(0),  //hrir_coeff_addr
    .clka(clk_100mhz), .wea(1'b0), .ena(1'b1), //left_hrir_ready_read
    .rsta(sys_rst), .regcea(1'b1), .douta(hrir_left_ram_data_out)         
  );


  xilinx_single_port_ram_read_first #(
      .RAM_WIDTH(32),                              // Specify RAM data width for HRIR coefficients
      .RAM_DEPTH(TOTAL_NUM_COEFFS),                            // Specify RAM depth (number of entries) 25 * 200
      .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
      .INIT_FILE(`FPATH(hrir_r_bs30_azi_full.mem)) //all azimuths with same bram, should just have pointer                  
  ) 
  hrir_right_coeff_brom (
    .addra(addrb), .dina(0), //hrir_coeff_addr
    .clka(clk_100mhz), .wea(1'b0), .ena(1'b1), //right_hrir_ready_read
    .rsta(sys_rst), .regcea(1'b1), .douta(hrir_right_ram_data_out)         
  );

  // *************************************************************************** //


  // ***************************** FIR FILTER ********************************** //
    
    

    logic signed [$clog2(NUM_AZIMUTHS) - 1:0] azimuth, neg_one;
    logic fir_busy, ws_out, fir_valid_out;
    // logic [FIR_OUT_WIDTH - 1: 0] fir_out;
    logic [AUDIO_WORD_WIDTH-1:0] audio_sample_buffer; 

    logic [AUDIO_WORD_WIDTH - 1:0] left_out;
    logic [AUDIO_WORD_WIDTH - 1:0] right_out;

    logic db_btn_out1, db_btn_out2;
    assign neg_one = 5'b11111;

    debouncer btn1_db(
      .clk_in(clk_in),
      .rst_in(sys_rst),
      .dirty_in(btn[1]),
      .clean_out(db_btn_out1)); //right button

    debouncer btn2_db(
      .clk_in(clk_in),
      .rst_in(sys_rst),
      .dirty_in(btn[2]),
      .clean_out(db_btn_out2)); //left button

    always_ff @(posedge clk_in) begin
      if (sys_rst) begin 
        azimuth <= 0;
      end else begin
        if (db_btn_out2) begin
          if (azimuth == 0) azimuth <= NUM_AZIMUTHS - 1;
          else azimuth <= azimuth + neg_one;
        end else if (db_btn_out1) begin
          if (azimuth == NUM_AZIMUTHS - 1) azimuth <= 0;
          else azimuth <= azimuth + 1;
        end

      end
    end

    // always_ff @(posedge clk_in) begin
    //   if (sys_rst) fir_out <= 0;
    //   else if (fir_valid_out) begin 
    //     if (!ws_out) left_out <= fir_out[28:3]; //most info
    //     else right_out <= fir_out[28:3];
    //   end
    // end

    fir_filter #(
      .HRIR_COEFF_BIT_WIDTH(32),
      .AUDIO_WORD_WIDTH(AUDIO_WORD_WIDTH),
      .NUM_AZIMUTHS(NUM_AZIMUTHS),
      .NUM_LOAD_MULT_TERMS(8),
      .FIR_OUTPUT_BIT_WIDTH(FIR_OUT_WIDTH),
      .NUM_TOTAL_TERMS(200)
    ) fir ( 
      .clk_in(clk_100mhz),
      .rst_in(sys_rst),   
      .start(1'b1),                 // falling edge of SCK 
      .audio_sample_in(doutb),       //signed [AUDIO_WORD_WIDTH - 1: 0]
      .coeff_in(hrir_ram_data_out_buffer),  //signed [HRIR_COEFF_BIT_WIDTH - 1: 0] 
      .ws_in(ws_in),                 // left (0) or right (1) channel
      .azimuth_in(azimuth),          // [$clog2(NUM_AZIMUTHS) - 1: 0] (signed, but always non-neg)
      .load_ready(hrir_ready_read),
      .fir_busy(fir_busy),           //if low, in mult_stage
      .ws_out(ws_out),               //out
      .fir_valid_out(fir_valid_out), //out
      .audio_sample_out(audio_sample_buffer),   //[NUM_TOTAL_TERMS - 1: 0] [AUDIO_WORD_WIDTH - 1: 0] 
      .fir_out(fir_out)                         //[FIR_OUTPUT_BIT_WIDTH - 1: 0] 
      

  );
  assign led = fir_out[15:0];

  // *************************************************************************** //
    
  
endmodule // top_level
`default_nettype wire





