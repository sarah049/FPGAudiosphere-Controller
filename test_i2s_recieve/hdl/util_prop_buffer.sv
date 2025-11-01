module prop_buffer #(
    parameter STAGES_NEEDED,
    parameter DATA_WIDTH 
) (  
    input wire clk_in,
    input wire [DATA_WIDTH-1:0]  data_in,
    input wire data_new,
    output logic [DATA_WIDTH-1:0] data_out
    );

    logic [DATA_WIDTH-1:0] data_pipe [STAGES_NEEDED-1:0];

    assign data_out = data_pipe[STAGES_NEEDED-1];

    always_ff @(posedge clk_in)begin

        data_pipe[0] <= (data_new) ? data_in : data_pipe[0];
        for (int i=1; i<STAGES_NEEDED; i = i+1)begin
            data_pipe[i] <= (data_new) ? data_pipe[i-1] : data_pipe[i];
        end
    end
endmodule