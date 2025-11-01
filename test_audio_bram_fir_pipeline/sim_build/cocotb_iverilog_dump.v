module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/cespalv/MIT/Sophomore Year/6.111/Labs/FinalProject/FPGAudioSphere/test_audio_bram_fir_pipeline/sim_build/top_level.fst");
    $dumpvars(0, top_level);
end
endmodule
