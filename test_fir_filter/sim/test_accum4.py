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
    dut.ready.value = 1

    await ClockCycles(dut.clk_in,3)
    # dut.tap_values_in.value = [0b11_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111,0b00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001]

    # dut.tap_values_in.value = 0b11_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_11_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111
    dut.tap_values_in.value = 0b11_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_11_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_11_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_11_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111
    for i in range(8):
        await ClockCycles(dut.clk_in,1)
        if i > 2: # at i = 3, accum_out value is correct
            dut._log.info(f"cycle: {i}")
            # dut._log.info(f"i val: {dut.i.value}")
            dut._log.info(f"busy: {dut.tree_accum_busy.value}")
            dut._log.info(f"valid_out: {dut.valid_out.value}")
            dut._log.info(f"state: {dut.state.value}")
            dut._log.info(f"regs: {dut.reg_sum_stage1.value}")
            dut._log.info(f"taps: {dut.tap_values_in.value}")
            dut._log.info(f"accum4_out: {bin(dut.accum_out.value)}")
        else:
            dut._log.info(f"cycle: {i}")
            dut._log.info(f"regs: {dut.reg_sum_stage1.value}")
    # dut._log.info(f"accum_out: {dut.accum_out.value}")
    



    
    
#findings: adding 4 62-bit 1s = 64-bit 4, adding 2 62-bit 1s and 2 62-bit -1s = 64-bit 0


def is_runner():
    """Image Sprite Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "fir_tree_accum_4.sv"]
    sources += [proj_path / "hdl" / "fir_tree_accum_8.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="fir_tree_accum_4",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="fir_tree_accum_4",
        test_module="test_accum4",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()
