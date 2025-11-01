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
    await ClockCycles(dut.clk_in,2)
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in,2)
    

    i = 0
    dut._log.info(f"cycle: {i}")
    dut._log.info(f"azimuth: {dut.azimuth_out.value}")
    await ClockCycles(dut.clk_in,1)

    dut.left_btn.value = 1
    await ClockCycles(dut.clk_in,1)
    i += 1
    dut.left_btn.value = 0
    await ClockCycles(dut.clk_in,1)
    dut._log.info(f"cycle: {i}")
    dut._log.info(f"azimuth: {dut.azimuth_out.value}")


    dut.right_btn.value = 1
    await ClockCycles(dut.clk_in,1)
    i += 1
    dut.right_btn.value = 0
    await ClockCycles(dut.clk_in,1)
    dut._log.info(f"cycle: {i}")
    dut._log.info(f"azimuth: {dut.azimuth_out.value}")





    
    # for i in range(10):
    #     await ClockCycles(dut.clk_in,1)
    #     if i > 2: # at i = 3, accum_out value is correct
    #         dut._log.info(f"cycle: {i}")
    #         # dut._log.info(f"i val: {dut.i.value}")
    #         dut._log.info(f"busy: {dut.tree_accum_busy.value}")
    #         dut._log.info(f"valid_out: {dut.valid_out.value}")
    #         dut._log.info(f"state: {dut.state.value}")
    #         dut._log.info(f"regs: {dut.reg_sum_stage1.value}")
    #         dut._log.info(f"taps: {dut.tap_values_in.value}")
    #         dut._log.info(f"accum4_out: {bin(dut.accum_out.value)}")
    #     else:
    #         dut._log.info(f"cycle: {i}")
    #         dut._log.info(f"regs: {dut.reg_sum_stage1.value}")
    


def is_runner():
    """Image Sprite Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "azimuth.sv"]
    sources += [proj_path / "hdl" / "debouncer.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="azimuth",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="azimuth",
        test_module="test_azimuth",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()
