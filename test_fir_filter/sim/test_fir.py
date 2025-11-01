import cocotb
import os
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,with_timeout
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner


@cocotb.test()
async def test_a(dut):
    """cocotb test for fir_filter"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in,1)
    dut.rst_in.value = 0
    dut.start.value = 1
    dut.azimuth_in.value = 0
    dut.ws_in.value = 0
    await ClockCycles(dut.clk_in,3)
    audio_in = 0b0000_0000_0000_0000_0000_0001
    # audio_in = 0b1111_1111_1111_1111_1111_1111 #-1
    # audio_in = 0b1111_1111_1111_1111_0011_1000
    # dut.audio_sample_in.value = audio_in

    dut._log.info(f"NUM_TOTAL_TERMS: {dut.NUM_TOTAL_TERMS.value}")

    # await ClockCycles(dut.clk_in,3)
    # i = 0
    state_counts = {
        0: 0,
        1: 0,
        2: 0,
        3: 0,
        4: 0,
        5: 0
    } # {0: 2, 1: 256, 2: 32, 3: 64, 4: 16, 5: 3}

    flag = False

    for i in range(373):
        
        dut.ws_in.value = 1
        # if -1 < i < 25:
        dut._log.info("----------")
        dut._log.info(f"cycle: {i}")
        state = dut.fir_state.value
        dut._log.info(f"state: {state}")
        dut._log.info(f"buffer: {dut.ws_buffer.value}")
        if i==0:
            dut.audio_sample_in.value = audio_in
            audio_in += 1
            dut.coeff_in.value = 0b0000_0000_0000_0000_0000_0000_0000_0001 #positive numbers
            # dut.coeff_in.value = 0b1111_1111_1111_1111_1111_1111_1111_1111

        # i += 1
        if state == 1: 
            if audio_in < 201: #in load_mult stage
                dut.audio_sample_in.value = audio_in
                audio_in += 1
            dut._log.info(f"total_terms_count : {dut.total_terms_count.value }")
            # dut._log.info(f"test_b : {dut.test_b.value }")
            # dut.coeff_in.value = 0b0000_0000_0000_0000_0000_0000_0000_0001
            if 30 < i < 40:            
                dut._log.info(f"audio_sample_in: {dut.audio_sample_in.value}")

                # if dut.tree_accuma_out_registers.value:
                #     dut._log.info(f"tree_accuma_out_registers {dut.tree_accuma_out_registers.value}")
                # if dut.tree_accumb_out_registers.value:
                #     dut._log.info(f"tree_accumb_out_registers {dut.tree_accumb_out_registers.value}")
        state_counts[state] += 1
        # if flag:
        #     flag = False

        if state == 3:
            flag = True
            await RisingEdge(dut.clk_in)
            dut._log.info(f"mult_out: {dut.mult_out.value}")
            dut._log.info(f"accuma_valid_out: {dut.accuma_valid_out.value}")
            dut._log.info(f"tree_accuma_out_temp {dut.tree_accuma_out_temp.value}")
            dut._log.info(f"tree_accuma_out_registers {dut.tree_accuma_out_registers.value}")
            dut._log.info(f"reg_sum_stage1a {dut.reg_sum_stage1a.value}")
            dut._log.info(f"reg_sum_stage2a {dut.reg_sum_stage2a.value}")
        
        if state == 4:
            dut._log.info(f"tree_accumb_out_registers: {dut.tree_accumb_out_registers.value}")
            dut._log.info(f"accumc_valid_out: {dut.accumc_valid_out.value}")
            # dut.coeff_in.value = 0b1111_1111_1111_1111_1111_1111_1111_1111 #0b0000_0000_0000_0000_0000_0001
        '''
            if dut.tree_accuma_out_registers.value:
                dut._log.info(f"tree_accuma_out_registers {dut.tree_accuma_out_registers.value}")
            if dut.tree_accumb_out_registers.value:
                dut._log.info(f"tree_accumb_out_registers {dut.tree_accumb_out_registers.value}")
        if dut.fir_state.value == 2:

            if i < 50:  # multiply result shows up at 
                dut._log.info(f"cycle_offset: {dut.cycle_offset.value}")
                dut._log.info(f"mult_out: {dut.mult_out.value}")
        elif dut.fir_state.value == 3: # multiply results
                # dut._log.info(f"testb: {dut.test_b.value}")
            if i <50: #tree_accuma results at cycle 19
                # dut._log.info(f"tree_accum_wait_count: {dut.tree_accum_wait_count.value}")
                dut._log.info(f"mult_out: {dut.mult_out.value}")
                dut._log.info(f"accuma_valid_out: {dut.accuma_valid_out.value}")
                dut._log.info(f"tree_accuma_out_temp {dut.tree_accuma_out_temp.value}")
                dut._log.info(f"tree_accuma_out_registers {dut.tree_accuma_out_registers.value}")
        if dut.fir_state.value == 4 or dut.tree_accumb_out_temp.value or dut.tree_accumb_out_temp.value: # tree_accumb, cycle 167
            dut._log.info(f"cycle: {i}")
            dut._log.info(f"state: {dut.fir_state.value}")
            dut._log.info(f"accuma_cycle_count: {dut.accuma_cycle_count.value}")
            dut._log.info(f"accumb_cycle_count: {dut.accumb_cycle_count.value}")
            # dut._log.info(f"tree_accum_wait_count: {dut.tree_accum_wait_count.value}")
            dut._log.info(f"accumb_valid_out: {dut.accumb_valid_out.value}")
            dut._log.info(f"tree_accumb_out_temp {dut.tree_accumb_out_temp.value}")
            dut._log.info(f"tree_accumb_out_registers {dut.tree_accumb_out_registers.value}")
        if 40 < i <45:
            dut._log.info(f"tree_accumb_out_temp {dut.tree_accumb_out_temp.value}")
            dut._log.info(f"tree_accumb_out_registers {dut.tree_accumb_out_registers.value}")

        if  19 <i < 27 :
        #load_mult:
            # dut._log.info(f"cycle: {i}")
            dut._log.info(f"audio_sample_in: {dut.audio_sample_in.value}")
            dut._log.info(f"total_terms_count: {dut.total_terms_count.value}")
            dut._log.info(f"audio_word_registers: {dut.audio_word_registers.value}")
            dut._log.info(f"load_mult_ix val: {dut.load_mult_ix.value}")
        
        '''
        await ClockCycles(dut.clk_in,1)
        dut._log.info(f"fir out: {dut.fir_out.value}")
        
        #tree accuma:

            # dut._log.info(f"cycle: {i}")
            # dut._log.info(f"tree_accuma: {dut.tree_accuma_out_temp.value}")
            # # dut._log.info(f"mult_ix val: {dut.mult_ix.value}")
            # dut._log.info(f"accuma busy: {dut.accuma_busy.value}")
            # dut._log.info(f"accuma_valid_out: {dut.accuma_valid_out.value}")

            # dut._log.info(f"regs: {dut.reg_sum_stage1.value}")
            # dut._log.info(f"taps: {dut.tap_values_in.value}")
            # dut._log.info(f"accum4_out: {bin(dut.accum_out.value)}")
    dut._log.info(state_counts)
#problem: when we move into non-load stage, we still have audio samples streaming in 
            #solution: can stop load_ready signal two cycles early in load_mult stage, and in the stage preceding the redirect to load_mult, make load_ready two cycles early 
#added test_a, test_b sig
# problem: tree additions are not parallelized (one by one rn, need to spell out);
    #ALSO fire bram early by 2 cycles before back to LOAD
    #correctly goes thru 200 cycles

    
'''
#findings: you can fire continuous stream of addresses
#fir_reg_signal = dut.top_level.fir_inst.fir_reg
#need to tb both tree_accum_4 and tree_accum_8
#load_mult works,
#multiply: 1* (1 thru 7) works, -1 * (1 thru 7 works)             
            
'''


def is_runner():
    """Image Sprite Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "fir_filter.sv"]
    sources += [proj_path / "hdl" / "fir_tree_accum_4.sv"]
    sources += [proj_path / "hdl" / "fir_tree_accum_8.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="fir_filter",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="fir_filter",
        test_module="test_fir",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()
