module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/smyl362/FPGAudioSphere/test_fir_tree/sim/sim_build/fir_filter.fst");
    $dumpvars(0, fir_filter);
end
endmodule
