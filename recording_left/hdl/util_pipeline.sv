module pipeline #(
    parameter STAGES_NEEDED,
    parameter DATA_WIDTH 
) (  
    input wire clk_in,
    input wire [DATA_WIDTH-1:0]  data_in,
    output logic [DATA_WIDTH-1:0] data_out
    );

    logic [DATA_WIDTH-1:0] data_pipe [STAGES_NEEDED-1:0];

    always_ff @(posedge clk_in)begin
        data_pipe[0] <= data_in;
        for (int i=1; i<STAGES_NEEDED; i = i+1)begin
            data_pipe[i] <= data_pipe[i-1];
        end
        data_out <= data_pipe[STAGES_NEEDED - 1];
    end
endmodule