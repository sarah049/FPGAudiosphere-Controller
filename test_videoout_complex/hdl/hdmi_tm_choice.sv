module tm_choice (
        input wire [7:0] data_in,
        output logic [8:0] qm_out
    );

    always_comb begin

        logic [8:0] result;
        logic [3:0]countOnes;
        countOnes = data_in[7] + data_in[6] + data_in[5] + data_in[4] + data_in[3] +  data_in[2] + data_in[1] + data_in[0];

        if ((countOnes == 4 && !data_in[0]) || (countOnes > 4)) begin // option 2

            result[8] = 1'b0;
            result[0] = data_in[0];

            for(int i = 1; i < 8; i++) begin
                result[i] = ~(data_in[i] ^ result[i-1]);
            end

        end else begin // option 1

            result[8] = 1'b1;
            result[0] = data_in[0];

            for(int i = 1; i < 8; i++) begin
                result[i] = data_in[i] ^ result[i-1];
            end
        end

        qm_out = result;
    end

endmodule