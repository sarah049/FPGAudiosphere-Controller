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
from itertools import chain


@cocotb.test()
async def test_a(dut):
    """cocotb test for fir_filter"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_100mhz_sys, 10, units="ns").start())
    
    await ClockCycles(dut.clk_100mhz_sys,2)
    dut.sys_rst.value = 1
    await ClockCycles(dut.clk_100mhz_sys,1000)
    dut.sys_rst.value = 0
    await ClockCycles(dut.clk_100mhz_sys,2)
    await ClockCycles(dut.clk_100mhz_sys,2)
    dut.sys_rst.value = 1
    await ClockCycles(dut.clk_100mhz_sys,1000)
    dut.sys_rst.value = 0
    await ClockCycles(dut.clk_100mhz_sys,2)


    for i in range(2200*50):
        await ClockCycles(dut.clk_100mhz_sys,1)

    
#findings: you can fire continuous stream of addresses
#fir_reg_signal = dut.top_level.fir_inst.fir_reg
#need to tb both tree_accum_4 and tree_accum_8
            #then 


def is_runner():
    """Image Sprite Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))

    hdl_path = proj_path / "hdl"
    sources = list(chain(hdl_path.glob("*.sv"), hdl_path.glob("*.v")))  # Include .sv and .v files
    


    # sources = [proj_path / "hdl" / "top_level_simple.sv"]
    # sources += [proj_path / "hdl" / "xilinx_single_port_ram_read_first.sv"]
    # sources += [proj_path / "hdl" / "fir_filter.sv"]
    # sources += [proj_path / "hdl" / "util_evt_counter.sv"]
    # sources += [proj_path / "hdl" / "fir_tree_accum_8.sv"]
    # sources += [proj_path / "hdl" / "fir_tree_accum_4.sv"]

    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="top_level",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="top_level",
        test_module="test_simple_tl",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()
