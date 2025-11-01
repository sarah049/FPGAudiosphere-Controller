module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/smyl362/FPGAudioSphere/test_audio_bram_fir_pipeline/sim/sim_build/top_level.fst");
    $dumpvars(0, top_level);
end
endmodule
