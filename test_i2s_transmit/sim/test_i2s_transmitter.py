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
    """cocotb test for image_sprite"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 100, units="ns").start())
    cocotb.start_soon(Clock(dut.sclk, 2, units="ns").start())

    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in,1)
    dut.rst_in.value = 1
    
    
    await ClockCycles(dut.clk_in,1)
    dut.data_valid.value = 1
    dut.rst_in.value = 0
    # dut._log.info(f"q_out value: {hex(dut.q_out.value)}")
    left_in = 0b1010_1111
    right_in = 0b0010_0010
    dut.data_left.value = left_in
    dut.data_right.value = right_in
    dut.ws.value = 0 # left channel data
    dut.on_last_cycle_bit.value =1 

    for i in range(23):
        await ClockCycles(dut.sclk, 1) 
        dut._log.info(f"data_out value: {dut.sd.value}")

    dut.ws.value = 1 # right channel data
    await ClockCycles(dut.sclk, 25)


    
    

    

def is_runner():
    """Image Sprite Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "i2s_transmitter.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="i2s_transmitter",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="i2s_transmitter",
        test_module="test_i2s_transmitter",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()
