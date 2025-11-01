module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/smyl362/FPGAudioSphere/test_i2s_transmit/sim/sim_build/i2s_transmitter.fst");
    $dumpvars(0, i2s_transmitter);
end
endmodule
