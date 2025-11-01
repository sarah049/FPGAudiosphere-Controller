`timescale 1ns / 1ps
`default_nettype none

//written in lecture!
//debounce_2.sv is a different attempt at this done after class with a few students
module  debouncer #(
  parameter CLK_PERIOD_NS = 10,
  parameter DEBOUNCE_TIME_MS = 500
) (   
  input wire clk_in,
  input wire rst_in,
  input wire dirty_in,
  output logic clean_out
  );
  
  //you will likely need to cast this:
  parameter COUNTER_MAX = int'($ceil(DEBOUNCE_TIME_MS*1_000_000/CLK_PERIOD_NS));
  parameter COUNTER_SIZE = $clog2(COUNTER_MAX);
  logic [COUNTER_SIZE-1:0] counter;
  logic current; 
  logic old_dirty_in;
  assign clean_out = current;

  always_ff @(posedge clk_in)begin 
    if (rst_in)begin
      counter <= 0;
      current <= dirty_in;
      old_dirty_in <= dirty_in;
    end else begin
      if (counter == COUNTER_MAX-1)begin
        current <= old_dirty_in;
        counter <= 0;
      end else if (dirty_in == old_dirty_in) begin
        counter <= counter +1;
      end else begin
        counter <= 0;
      end
    end
    old_dirty_in <= dirty_in;
  end
endmodule

`default_nettype wire

/*
`default_nettype none

module  debouncer #(parameter CLK_PERIOD_NS = 10,
                    parameter DEBOUNCE_TIME_MS = 5
                    )
  ( input wire clk_in,
    input wire rst_in,
    input wire dirty_in,
    output logic clean_out);
  localparam DEBOUNCE_CYCLES = $ceil(1_000_000*DEBOUNCE_TIME_MS/CLK_PERIOD_NS);
  localparam COUNTER_SIZE = $clog2(DEBOUNCE_CYCLES);
  logic [COUNTER_SIZE-1:0] counter;
  logic old_dirty_in; //need to remember
  always_ff @(posedge clk_in)begin
    old_dirty_in <= dirty_in;
    if(rst_in)begin
      clean_out <= dirty_in;
      counter <= 0;
    end else begin//normal operation:
      if(dirty_in != old_dirty_in)begin //if change on button, reset counter
        counter <= 0;
      end else if(counter==DEBOUNCE_CYCLES-1)begin //o.w. runs up and inc the counter
        clean_out <= dirty_in;
      end else begin
        counter <= counter + 1;
      end
    end
  end

endmodule


`default_nettype wire
*/