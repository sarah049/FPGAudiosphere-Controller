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

coeff_in_left = [0x0, 0x0, 0x0, 0x0, 0x2c, 0x43f, 0xffffe91e, 0x72a2, 0xfffd3263, 0x131a5, 0xfff716e9, 0xffdca949, 0xfffd5953, 0x70e879, 0x5a2dda, 0xff75920b, 0xffde4861, 0xff252a91, 0x21c08e, 0xb9b8, 0xff5621c1, 0xc50cbe, 0xfe8648f6, 0x14d917c, 0xff82ba87, 0xfe191b04, 0x206b33e, 0xff6995d7, 0x9f38935, 0x3553093b, 0x1d5ce35f, 0xec8c2c52, 0x2181b1d, 0xea808ec6, 0xe67f322c, 0xfe1282, 0xf2913fd8, 0xe72cd4c6, 0xe47b1839, 0xec3fca9, 0x3cd0236a, 0x88cb191, 0xe4f9aba5, 0xf9f19872, 0xeb322a7b, 0xf358e160, 0xb7f14b7, 0xfdeafb17, 0xef206c52, 0xffa31d5c, 0xc4b0cb, 0xff3ca6e3, 0xb8b83ea, 0xf7d233f5, 0xf598109a, 0x3e85762, 0x3c1d1b, 0xfeb9e7e0, 0x32d746a, 0xd28fdb, 0xfe90880a, 0x370baaf, 0xfe96f13c, 0xfdb162b6, 0xff6a1cd3, 0xfdca2e87, 0x9d34bc, 0xff0dca98, 0xfebbffc0, 0x304f044, 0x2321e39, 0xff315b08, 0x24ccbd, 0xffdf34f1, 0xfe544cee, 0x1195c02, 0x940321, 0xfdf0a30f, 0xffdb3e82, 0xd2ccec, 0xffda2b4f, 0x12839af, 0xf57907, 0xfefd261e, 0xffa24944, 0xff5db88d, 0xfef89a66, 0x3379ca, 0xffda7bee, 0x923b2e, 0xe5ec95, 0xff48d7dd, 0xfeaab810, 0xff92ed0a, 0xffe15e80, 0xdd31, 0xa0d1ba, 0x4d03b0, 0x220f76, 0x5f00c9, 0x3ca802, 0xf880e3, 0xf29109, 0xff51657e, 0xfef59342, 0xffbcaca2, 0xffb07ffd, 0x3d33f5, 0x14b176e, 0xe3e3e2, 0x35830b, 0x58f561, 0xa8cce5, 0xe075c3, 0x3cbf9, 0xff7c89d8, 0x4fa6bf, 0x31f575, 0xffd99835, 0x56ef7a, 0x7856d8, 0x80f7b, 0xffb30bff, 0xff9eeec6, 0xff72b3e9, 0xff74d623, 0xff5d43ac, 0xff181bfe, 0xffc1aa04, 0x16f6c8, 0x133e5c, 0x85e5dd, 0x47bccc, 0xffd583b4, 0xffb3112a, 0xff7eb3dc, 0xff12fb96, 0xff08e166, 0xffb1bb0d, 0xfff5e7e9, 0xfffb598e, 0x68cab0, 0xa84777, 0xabcec7, 0x5eaef4, 0x32a6f8, 0xfff407f7, 0xff955345, 0xff99e923, 0xffca07fe, 0xffa690a5, 0xffa675a4, 0xfff99411, 0xffd87751, 0xff2f7803, 0xfef9d618, 0xff7f3620, 0xff313401, 0xfee9c0e8, 0xffd0e891, 0x50bae, 0x3d31d7, 0xd9d036, 0xffe743e7, 0xff3f32f3, 0xffdda6e1, 0x64df43, 0x623e23, 0xff4db4af, 0xff206df7, 0x5a2382, 0x521570, 0x3987a6, 0x995da2, 0xfff62807, 0xff938996, 0xffc838d8, 0xf7f59, 0x5ff256, 0x232758, 0xffa5f953, 0xffacd15a, 0xfffcabc5, 0xcff82, 0x4b44, 0xffeee119, 0xffe228b0, 0xfffe867e, 0x1ce51, 0xfff0305a, 0x124b5, 0xfffada2a, 0xffe8d40c, 0xfffb6247, 0xfffc55f2, 0xffe731c9, 0xffeeb44c, 0x1864c, 0x2f5f6, 0xfffefc23, 0x0, 0x0, 0x0, 0x0, 0x3, 0x2f8, 0xfffff365, 0x2d6f, 0xffff60b2, 0xfffc88c2]

import scipy.io
import numpy as np

import mmap


# Ensure the directory exists
if not os.path.exists('../hrir'):
    # os.makedirs('hrir')
    print('hrir not found')



@cocotb.test()
async def test_a(dut):
    """cocotb test for fir_filter"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())

    

    ###start fpga logic
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in,1)
    dut.rst_in.value = 0
    dut.start.value = 1
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
    save = 0

    waits = []
    wait_count = 0
    load_count = 0

    for i in range(450):
        
        dut.ws_in.value = 1
        # if -1 < i < 25:
        dut._log.info("----------")
        dut._log.info(f"cycle: {i}")
        state = dut.fir_state.value
        dut._log.info(f"state: {state}")
        dut._log.info(f"buffer: {dut.ws_buffer.value}")
        if i==0:
            dut.audio_sample_in.value = audio_in
            # audio_in += 1
            # dut.coeff_in.value = 0b0000_0000_0000_0000_0000_0000_0000_0001 #positive numbers
            
            # dut.coeff_in.value = coeff_in_left[i+16]
            dut.coeff_in.value = coeff_in_left[save]
            # dut.coeff_in.value = 0b1111_1111_1111_1111_1111_1111_1111_1111
        # if dut.load_ready.value:
        #     waits.append(wait_count)
        #     load_count += 1
        # else:
        #     wait_count += 1
        # i += 1
        if state == 1: 
            if  dut.load_wait.value == 3:
                load_count += 1
            if save < 200 and  dut.load_wait.value == 3 : #in load_mult stage
                save += 1
                # dut.coeff_in.value = coeff_in_left[i+15] # i-1 start
                dut.coeff_in.value = coeff_in_left[save] # i-1 start
                # dut._log.info(hex(coeff_in_left[save]))
                # save = i

            dut._log.info(f"total_terms_count : {dut.total_terms_count.value }")
            # dut._log.info(f"test_b : {dut.test_b.value }")
            # dut.coeff_in.value = 0b0000_0000_0000_0000_0000_0000_0000_0001

            # if  i < 20:            
            #     dut._log.info(f"audio_sample_in: {dut.audio_sample_in.value}")

            #     if dut.tree_accuma_out_registers.value:
            #         dut._log.info(f"tree_accuma_out_registers {dut.tree_accuma_out_registers.value}")
            #     if dut.tree_accumb_out_registers.value:
            #         dut._log.info(f"tree_accumb_out_registers {dut.tree_accumb_out_registers.value}")
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
        
        if state == 4 or state == 5:
            dut._log.info(f"tree_accumb_out_registers: {dut.tree_accumb_out_registers.value}")
            dut._log.info(f"accumc_valid_out: {dut.accumc_valid_out.value}")
            dut._log.info(f"fir valid out: {dut.fir_valid_out.value}")
            

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
        if state ==0:
            dut._log.info(f"fir out: {dut.fir_out.value}")
            dut._log.info(f"fir valid out: {dut.fir_valid_out.value}")
        
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
    dut._log.info(coeff_in_left[save])
    dut._log.info(load_count)
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
        test_module="test_fir2",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()
