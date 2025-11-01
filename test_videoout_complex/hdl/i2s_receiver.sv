module i2s_receiver #(
    parameter AUDIO_WORD_WIDTH = 24
) (
    // System
    input wire clk_in, 
    input wire rst_in, 

    // I2S Communcation
    input wire fsync,
    input wire ws,
    input wire sck,
    input wire sd,
    
    // FPGA outputs
    output logic [AUDIO_WORD_WIDTH-1:0] data_out,
    output logic channel_out,
    output logic valid_out 
);

    // State Logics
    logic [AUDIO_WORD_WIDTH-1:0] data_buffer; // Serial Data Buffer
    logic prev_fsync;
    logic prev_ws;
    logic prev_sck;

    logic start_frame;
    logic end_frame;
    assign start_frame = fsync && !prev_fsync; // Rising edge of FSYNC
    assign end_frame   = !fsync && prev_fsync; // Falling Edge of FSYNC

    logic sample_bit;
    assign sample_bit = sck && !prev_sck;       // Rising edge of SCK
   

    // Output Logics
    logic [AUDIO_WORD_WIDTH-1:0] data_out_r; // Final Registered data
    logic channel_out_r;
    logic valid_out_r;

    assign data_out    = data_out_r;
    assign channel_out = channel_out_r;
    assign valid_out   = valid_out_r;



    always_ff @(posedge clk_in) begin

      if (rst_in) begin // ********************** Reset 

          data_buffer <= 0;
          prev_fsync  <= 0;
          prev_sck    <= 0;
          prev_ws     <= 0;

          data_out_r <= 0;
          channel_out_r <= 0;
          valid_out_r <= 0;
      end else begin // ********************** Listening

        if(start_frame) begin 
          data_buffer <= 0;
          data_out_r <= 0;
          channel_out_r <= 0;
          valid_out_r <= 0;
        end else if (sample_bit)begin
          data_buffer <= {data_buffer[AUDIO_WORD_WIDTH-2:0], sd};
        end else if (end_frame) begin
          data_out_r <= data_buffer;
          channel_out_r <= ws;
          valid_out_r <= 1;
        end else begin
          valid_out_r <= 0;
        end
        
        prev_fsync <= fsync;
        prev_ws    <= ws;
        prev_sck   <= sck;
      end
    
    end 
endmodule


module i2s_buffer(
    input wire clk_in,
    input wire rst_in,

    input wire fsync_in,
    input wire sck_in,
    input wire ws_in,
    input wire sd_in,

    output logic fsync_out,
    output logic sck_out,
    output logic ws_out,
    output logic sd_out
);

  logic fsync_rxd_buffer_2, fsync_rxd_buffer_1;
  logic sck_rxd_buffer_2, sck_rxd_buffer_1;
  logic ws_rxd_buffer_2, ws_rxd_buffer_1;
  logic sd_rxd_buffer_2, sd_rxd_buffer_1;
  
  
  assign fsync_out = fsync_rxd_buffer_2;
  assign sck_out = sck_rxd_buffer_2;
  assign ws_out = ws_rxd_buffer_2;
  assign sd_out = sd_rxd_buffer_2;

  always_ff @( posedge clk_in ) begin
    if(rst_in) begin
      fsync_rxd_buffer_2 <= 0; fsync_rxd_buffer_1  <= 0;
      sck_rxd_buffer_2 <= 0; sck_rxd_buffer_1  <= 0;
      ws_rxd_buffer_2  <= 0;  ws_rxd_buffer_1  <= 0;
      sd_rxd_buffer_2  <= 0;  sd_rxd_buffer_1  <= 0;
    end else begin
      fsync_rxd_buffer_2 <= fsync_rxd_buffer_1; fsync_rxd_buffer_1  <= fsync_in;
      sck_rxd_buffer_2   <= sck_rxd_buffer_1;   sck_rxd_buffer_1 <= sck_in;
      ws_rxd_buffer_2    <= ws_rxd_buffer_1;    ws_rxd_buffer_1  <= ws_in;
      sd_rxd_buffer_2    <= sd_rxd_buffer_1;    sd_rxd_buffer_1  <= sd_in;
    end
  end           



endmodule