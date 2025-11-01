// -----------------  Time Domain Pulse Signal Crossing Synchronizer Header ------------------- //

// xpm_cdc_pulse: Pulse Transfer | Xilinx Parameterized Macro, version 2024.2
// xpm_cdc_pulse #(
//    .DEST_SYNC_FF(2),   // DECIMAL; range: 2-10
//    .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
//    .REG_OUTPUT(0),     // DECIMAL; 0=disable registered output, 1=enable registered output
//    .RST_USED(1),       // DECIMAL; 0=no reset, 1=implement reset
//    .SIM_ASSERT_CHK(0)  // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
// ) xpm_cdc_pulse_inst (
//    .dest_pulse(dest_pulse), // 1-bit output: Outputs a pulse the size of one dest_clk period when a pulse
//                             // transfer is correctly initiated on src_pulse input. This output is
//                             // combinatorial unless REG_OUTPUT is set to 1.

//    .dest_clk(dest_clk),     // 1-bit input: Destination clock.
//    .dest_rst(dest_rst),     // 1-bit input: optional; required when RST_USED = 1
//    .src_clk(src_clk),       // 1-bit input: Source clock.
//    .src_pulse(src_pulse),   // 1-bit input: Rising edge of this signal initiates a pulse transfer to the
//                             // destination clock domain. The minimum gap between each pulse transfer must be
//                             // at the minimum 2*(larger(src_clk period, dest_clk period)). This is measured
//                             // between the falling edge of a src_pulse to the rising edge of the next
//                             // src_pulse. This minimum gap will guarantee that each rising edge of src_pulse
//                             // will generate a pulse the size of one dest_clk period in the destination
//                             // clock domain. When RST_USED = 1, pulse transfers will not be guaranteed while
//                             // src_rst and/or dest_rst are asserted.

//    .src_rst(src_rst)        // 1-bit input: optional; required when RST_USED = 1
// );

// Notes:
//    Audio processor is working on 100 MHZ clock signal, so data must be written to Video BRAM at 100 MHz
//    however the BRAM that is written to changes dependent on the nf_hdmi signal which comes from the video_sig_gen
//    All video logic however runs on the pixel clock ~75.25 MHz for HDMI. Thererfore, the write side of the BRAM needs logic from both 100MHz and 72MHz
//    So, we read signals from the slower time domain and cross into the faster one. The 100MHz can sample the 72MHz twice every cycle 

/////////////////////////////////////////////////////////////////////////////







module video_controller(
    //System
    input wire clk_100mhz,
    input wire clk_pixel,
    input wire clk_5x,
    input wire rst_in_100mhz,
    input wire rst_in,

    // IO
    input wire last_cycle_audio,  
    input wire [23:0] og_data,
    input wire [23:0] left_data,
    input wire [23:0] right_data,
    input wire data_valid,

    //HDMI
    output logic [2:0]  hdmi_tx_p, 
    output logic [2:0]  hdmi_tx_n, 
    output logic        hdmi_clk_p, 
    output logic        hdmi_clk_n

);

  // Center of the Universe (current outgoing pixel)
  logic [23:0] pixel; 
  logic [7:0] red,green,blue; 
  assign red = pixel[23:16];
  assign green = pixel[15:8];
  assign blue = pixel[7:0];


  // *********************** Video Signal Generator *************************** //
  logic             hsync_hdmi;
  logic             vsync_hdmi;
  logic [10:0]     hcount_hdmi;
  logic [9:0]      vcount_hdmi;
  logic       active_draw_hdmi;
  logic [5:0] frame_count_hdmi;
  logic                nf_hdmi;

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

  logic [10:0] hcount_hdmi_buffered;
  logic [9:0]  vcount_hdmi_buffered;
  logic active_draw_hdmi_buffered, vsync_hdmi_buffered, hsync_hdmi_buffered; 
  pipeline  #(.STAGES_NEEDED(2), .DATA_WIDTH(11)) p1 (.clk_in(clk_pixel), .data_in(hcount_hdmi),      .data_out(hcount_hdmi_buffered));
  pipeline  #(.STAGES_NEEDED(2), .DATA_WIDTH(10)) p2 (.clk_in(clk_pixel), .data_in(vcount_hdmi),      .data_out(vcount_hdmi_buffered));
  pipeline  #(.STAGES_NEEDED(2), .DATA_WIDTH(1))  p3 (.clk_in(clk_pixel), .data_in(active_draw_hdmi), .data_out(active_draw_hdmi_buffered));
  pipeline  #(.STAGES_NEEDED(2), .DATA_WIDTH(1))  p4 (.clk_in(clk_pixel), .data_in(hsync_hdmi),       .data_out(hsync_hdmi_buffered));
  pipeline  #(.STAGES_NEEDED(2), .DATA_WIDTH(1))  p5 (.clk_in(clk_pixel), .data_in(vsync_hdmi),       .data_out(vsync_hdmi_buffered));
  // *************************************************************************** //



  // *********************** Graphis & Data management*************************** //
  logic prev_bram_sel, bram_sel, bram_sel_buffered, bram_sel_100mhz;
  pipeline  #(.STAGES_NEEDED(2), .DATA_WIDTH(1)) p10 (.clk_in(clk_pixel), .data_in(bram_sel), .data_out(bram_sel_buffered));

  assign bram_sel = (nf_hdmi) ? ~prev_bram_sel : prev_bram_sel;
  always_ff @(posedge clk_pixel) begin 
    prev_bram_sel <= (rst_in) ? 0 : bram_sel;
  end
  




  // Visual Parameters
  localparam IN_YSTART = 40;
  localparam OUT_YSTART = 320;
  localparam XSTART = 32;
  localparam GWIDTH = 735;
  localparam GHEIGHT = 256;

  // Determining Drawing Region
  typedef enum {NONE, IWAVE, OWAVE, AZI, GUI} drawing_region; 
  drawing_region region; 
  drawing_region region_b1;
  drawing_region region_buffered;

  always_ff @(posedge clk_pixel) begin
    if(rst_in) begin
      region_b1 <= NONE;
      region_buffered <= NONE;
    end else begin
      region_b1 <= region;
      region_buffered <= region_b1;
    end
  end


  // pipeline  #(.STAGES_NEEDED(2), .DATA_WIDTH(3)) p7 (.clk_in(clk_pixel), .data_in(region),  .data_out(region_buffered));

  logic x_within_graph;
  assign x_within_graph = (XSTART <= hcount_hdmi && hcount_hdmi < XSTART + GWIDTH);

  always_comb begin
    // if((OUT_YSTART < vcount_hdmi && vcount_hdmi < OUT_YSTART + GHEIGHT) ) begin
    //   region = GUI;
    // end else if (x_within_graph && (IN_YSTART <= vcount_hdmi && vcount_hdmi < IN_YSTART + GHEIGHT)) begin
    //   region = IWAVE;
    // end else begin
    //   region = NONE;
    // end 

    if (x_within_graph && (IN_YSTART <= vcount_hdmi && vcount_hdmi < IN_YSTART + GHEIGHT)) begin
      region = IWAVE;
    end else if (x_within_graph && (OUT_YSTART <= vcount_hdmi && vcount_hdmi < OUT_YSTART + GHEIGHT)) begin
      region = OWAVE;
    end else begin
      region = AZI;
    end 
  end


  // HV count offset
  logic [10:0] hcount_offset;
  logic [9:0] vcount_offset, vcount_offset_buffered;
  pipeline  #(.STAGES_NEEDED(2), .DATA_WIDTH(10)) p8 (.clk_in(clk_pixel), .data_in(vcount_offset),  .data_out(vcount_offset_buffered));
  assign hcount_offset = hcount_hdmi - XSTART;
  assign vcount_offset = vcount_hdmi - ((region == NONE) ? 0 : ((region == IWAVE) ? IN_YSTART : OUT_YSTART));


  //Data I/O
  logic [23:0] data_in;
  logic [23:0] data_out_null, data_out_one, data_out_sel;
  assign data_out_sel = (bram_sel_buffered) ? data_out_null : data_out_one;

  logic [7:0] offset_og, offset_left, offset_right;
  assign offset_og = data_out_sel[23:16];
  assign offset_left = data_out_sel[15:8];
  assign offset_right = data_out_sel[7:0];
  

  // Selecting Pixel
  logic [23:0] pixel_azi, pixel_in, pixel_out, pixel_gui;
 
  assign pixel_in = (vcount_offset_buffered[7:0] == offset_og) ? 24'h0000FF : 0;
  assign pixel_out = (vcount_offset_buffered[7:0] == offset_left ) ? 24'hFF0000 : (vcount_offset_buffered[7:0] == offset_right) ? 24'h0FF000 : 0;
  assign pixel_gui = 24'hFF0000;
  hdmi_pattern a (.x(hcount_hdmi_buffered), .y(vcount_hdmi_buffered), .pixel_color(pixel_azi));

  always_comb begin
    case (region_buffered)
        NONE:   pixel = 0;         // Output zero in IDLE state
        IWAVE:  pixel = pixel_in;       // Pass input to output in READ state
        OWAVE:  pixel = pixel_out;      // Invert input in WRITE state
        AZI:    pixel = pixel_azi;         // Output all ones in ERROR state
        GUI:    pixel = pixel_gui;
    endcase
  end

  

  // Data 
  localparam BRAM_DEPTH = 735;                
  localparam ADDR_WIDTH = $clog2(BRAM_DEPTH); 
  localparam DATA_WIDTH = 24;

  logic [ADDR_WIDTH-1:0] read_addr;
  assign read_addr = (hcount_offset >= BRAM_DEPTH) ? BRAM_DEPTH-1: hcount_offset;


  // !!!!!!!!!!!! NEW FRAME AND BSEL @ 75.25 MHZ CLOCK ... CROSS DOMAIN -> 100 MHZ CLOCK THROUGH SYNCRHONZIER !!!!!!!!!!!!!!!!!!!! 

  xpm_cdc_pulse #( .DEST_SYNC_FF(2), .INIT_SYNC_FF(0), .REG_OUTPUT(0), .RST_USED(1), .SIM_ASSERT_CHK(0) ) 
  xpm_cdc_pulse_inst (.dest_pulse(nf_hdmi_100mhz), .dest_clk(clk_100mhz), .dest_rst(rst_in_100mhz), .src_clk(clk_pixel), .src_pulse(nf_hdmi), .src_rst(rst_in));


  // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! 


  // !!!!!!!!!!!!!!!!!!!!!! WRITE LOGIC @ 100 MHZ CLOCK... CROSS DOMAIN -> 75.25MHZ CLOCK THROUGH BRAM !!!!!!!!!!!!!!!!!!!!!!!!!!!! 
  logic valid_write;
  logic [ADDR_WIDTH-1:0] write_addr;
  logic nf_hdmi_100mhz;

  always_ff @(posedge clk_100mhz) begin

    if(rst_in_100mhz) begin
      write_addr <= 0;
      valid_write <= 0;
      bram_sel_100mhz <= 0;

    end else begin  

      if(last_cycle_audio) begin 
        data_in <= (data_valid) ? {og_data[23:16] + 8'b0100_0000, left_data[23:16] + 8'b0100_0000, right_data[23:16] +  8'b0100_0000} : 0; // 
        valid_write <= 1;
      end else begin
        valid_write <= 0;
      end 

      write_addr <= (nf_hdmi_100mhz) ? 0 : ((last_cycle_audio) ? write_addr+1 : write_addr);
      bram_sel_100mhz <= (nf_hdmi_100mhz) ? ~bram_sel_100mhz : bram_sel_100mhz;

    end // -------------------------------------
  end
  // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! 



  xilinx_true_dual_port_read_first_2_clock_ram #(.RAM_WIDTH(DATA_WIDTH), .RAM_DEPTH(BRAM_DEPTH)) bram_null(
  // Write Null
  .addra(write_addr), .dina(data_in), .clka(clk_100mhz),
  .wea(~bram_sel_100mhz && valid_write), .ena(1), .rsta(rst_in_100mhz),
  .regcea(1'b1), .douta(),
  // Read Null
  .addrb(read_addr), .dinb(0), .clkb(clk_pixel),
  .web(1'b0), .enb(1), .rstb(rst_in),
  .regceb(1'b1), .doutb(data_out_null));

  xilinx_true_dual_port_read_first_2_clock_ram #(.RAM_WIDTH(DATA_WIDTH), .RAM_DEPTH(BRAM_DEPTH)) bram_one(
  // Write One
  .addra(write_addr), .dina(data_in), .clka(clk_100mhz),
  .wea(bram_sel_100mhz && valid_write), .ena(1), .rsta(rst_in_100mhz),
  .regcea(1'b1), .douta(),
  // Read One
  .addrb(read_addr), .dinb(0), .clkb(clk_pixel),
  .web(1'b0), .enb(1), .rstb(rst_in),
  .regceb(1'b1), .doutb(data_out_one));


  // test_pattern_generator pattern(.hcount_in(hcount_hdmi), .vcount_in(vcount_hdmi), .red_out(red), .green_out(green), .blue_out(blue));
  // *************************************************************************** //



  // ********** HDMI output: No need to journey below here PLEASEEEEE  ********* //
  logic [9:0] tmds_10b    [0:2]; 
  logic       tmds_signal [2:0]; 

  tmds_encoder tmds_red(.clk_in(clk_pixel), .rst_in(rst_in), .data_in(red), .control_in(2'b0), .ve_in(active_draw_hdmi_buffered), .tmds_out(tmds_10b[2]));
  tmds_encoder tmds_green(.clk_in(clk_pixel), .rst_in(rst_in), .data_in(green), .control_in(2'b0), .ve_in(active_draw_hdmi_buffered), .tmds_out(tmds_10b[1]));
  tmds_encoder tmds_blue(.clk_in(clk_pixel),.rst_in(rst_in), .data_in(blue),  .control_in({vsync_hdmi_buffered,hsync_hdmi_buffered}), .ve_in(active_draw_hdmi_buffered), .tmds_out(tmds_10b[0]));

  tmds_serializer red_ser( .clk_pixel_in(clk_pixel), .clk_5x_in(clk_5x), .rst_in(rst_in),.tmds_in(tmds_10b[2]), .tmds_out(tmds_signal[2]));
  tmds_serializer green_ser(   .clk_pixel_in(clk_pixel), .clk_5x_in(clk_5x), .rst_in(rst_in), .tmds_in(tmds_10b[1]), .tmds_out(tmds_signal[1]));
  tmds_serializer blue_ser(    .clk_pixel_in(clk_pixel), .clk_5x_in(clk_5x), .rst_in(rst_in), .tmds_in(tmds_10b[0]), .tmds_out(tmds_signal[0]));
  
  OBUFDS OBUFDS_blue (.I(tmds_signal[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
  OBUFDS OBUFDS_green(.I(tmds_signal[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
  OBUFDS OBUFDS_red  (.I(tmds_signal[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
  OBUFDS OBUFDS_clock(.I(clk_pixel), .O(hdmi_clk_p), .OB(hdmi_clk_n));
  // ************************************************************************** //

endmodule

module hdmi_pattern (
    input logic [11:0] x,            // Current pixel x-coordinate
    input logic [11:0] y,            // Current pixel y-coordinate
    output logic [23:0] pixel_color  // Pixel color (RGB)
);

    // Parameters for the pattern
    parameter int CENTER_X = 900;   // Center x-coordinate (example for 1920x1080 resolution)
    parameter int CENTER_Y = 360;   // Center y-coordinate
    parameter int RADIUS = 250;     // Radius for smaller squares
    parameter int SIDE_CENTER = 15; // Half side length of center square
    parameter int SIDE_SMALL = 10;  // Half side length of smaller squares

    // Fixed-size array of angles in degrees
    localparam real angles[25] = {
        -80.0, -65.0, -55.0, -45.0, -40.0, -35.0, -30.0, -25.0, -20.0, -15.0,
        -10.0,  -5.0,   0.0,   5.0,  10.0,  15.0,  20.0,  25.0,  30.0,  35.0,
         40.0,  45.0,  55.0,  65.0,  80.0
    };

    // Helper function to convert degrees to radians
    function real to_radians(real degrees);
        return degrees * 3.141592653589793 / 180.0;
    endfunction

    // Combinational logic for determining pixel color
    always_comb begin
        pixel_color = 24'h000000; // Default to black

        // Check if the pixel is in the center square
        if ((x >= CENTER_X - SIDE_CENTER) && (x <= CENTER_X + SIDE_CENTER) &&
            (y >= CENTER_Y - SIDE_CENTER) && (y <= CENTER_Y + SIDE_CENTER)) begin
            pixel_color = 24'hFFFFFF; // White for the center square
        end else begin
            // Check if the pixel is in any smaller square
            for (int i = 0; i < 25; i++) begin
                real angle_rad = to_radians(angles[i]);
                int small_x = $rtoi(CENTER_X + RADIUS * $cos(angle_rad));
                int small_y = $rtoi(CENTER_Y + RADIUS * $sin(angle_rad)); // Flipped sign here

                if ((x >= small_x - SIDE_SMALL) && (x <= small_x + SIDE_SMALL) &&
                    (y >= small_y - SIDE_SMALL) && (y <= small_y + SIDE_SMALL)) begin
                    pixel_color = 24'hFF0000; // Red for smaller squares
                end
            end
        end
    end

endmodule

// module hdmi_pattern (
//     input logic [11:0] x,            // Current pixel x-coordinate
//     input logic [11:0] y,            // Current pixel y-coordinate
//     output logic [23:0] pixel_color  // Pixel color (RGB)
// );

//     // Parameters for the pattern
//     parameter int CENTER_X = 960;   // Center x-coordinate (example for 1920x1080 resolution)
//     parameter int CENTER_Y = 540;   // Center y-coordinate
//     parameter int RADIUS = 350;     // Radius for smaller squares
//     parameter int SIDE_CENTER = 20; // Half side length of center square
//     parameter int SIDE_SMALL = 15;  // Half side length of smaller squares

//     // Fixed-size array of angles in degrees
//     localparam real angles[25] = {
//         -80.0, -65.0, -55.0, -45.0, -40.0, -35.0, -30.0, -25.0, -20.0, -15.0,
//         -10.0,  -5.0,   0.0,   5.0,  10.0,  15.0,  20.0,  25.0,  30.0,  35.0,
//          40.0,  45.0,  55.0,  65.0,  80.0
//     };

//     // Helper function to convert degrees to radians
//     function real to_radians(real degrees);
//         return degrees * 3.141592653589793 / 180.0;
//     endfunction

//     // Combinational logic for determining pixel color
//     always_comb begin
//         pixel_color = 24'h000000; // Default to black

//         // Check if the pixel is in the center square
//         if ((x >= CENTER_X - SIDE_CENTER) && (x <= CENTER_X + SIDE_CENTER) &&
//             (y >= CENTER_Y - SIDE_CENTER) && (y <= CENTER_Y + SIDE_CENTER)) begin
//             pixel_color = 24'hFFFFFF; // White for the center square
//         end else begin
//             // Check if the pixel is in any smaller square
//             for (int i = 0; i < 25; i++) begin
//                 real angle_rad = to_radians(angles[i]);
//                 int small_x = $rtoi(CENTER_X + RADIUS * $cos(angle_rad));
//                 int small_y = $rtoi(CENTER_Y - RADIUS * $sin(angle_rad));

//                 if ((x >= small_x - SIDE_SMALL) && (x <= small_x + SIDE_SMALL) &&
//                     (y >= small_y - SIDE_SMALL) && (y <= small_y + SIDE_SMALL)) begin
//                     pixel_color = 24'hFF0000; // Red for smaller squares
//                 end
//             end
//         end
//     end

// endmodule

