"""
test_conv_pe.py — cocotb testbench stub for conv_pe.sv
Project: Edge CNN Accelerator (ECE510 Spring 2026)
COPT Part B — simulation harness
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


@cocotb.test()
async def test_conv_pe_reset(dut):
    """Verify active-high synchronous reset clears accumulator and outputs."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    dut.rst.value       = 1
    dut.valid_in.value  = 0
    dut.pixel_in.value  = 0
    dut.weight_in.value = 0

    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")   # let outputs settle out of X state

    assert dut.accum_out.value.to_signed() == 0, "accum_out not cleared by reset"
    assert dut.valid_out.value == 0,              "valid_out not cleared by reset"
    dut._log.info("Reset test PASS")


@cocotb.test()
async def test_conv_pe_accumulation(dut):
    """
    Feed a 3x3 kernel (KERNEL_SIZE=9) with pixel=1, weight=1 for all taps.
    Expected dot-product: 9 x (1x1) = 9.
    """
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    dut.rst.value       = 1
    dut.valid_in.value  = 0
    dut.pixel_in.value  = 0
    dut.weight_in.value = 0
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.rst.value = 0

    dut.valid_in.value = 1
    for _ in range(9):
        dut.pixel_in.value  = 1
        dut.weight_in.value = 1
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")

    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    result = dut.accum_out.value.to_signed()
    dut._log.info(f"3x3 all-ones dot product: accum_out = {result} (expected 9)")
    assert result == 9, f"Expected 9, got {result}"


@cocotb.test()
async def test_conv_pe_representative_input(dut):
    """
    Representative INT8 input: pixel values [1..9], weights [1..9].
    Expected dot-product: sum(i*i for i in 1..9) = 285.
    """
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    dut.rst.value       = 1
    dut.valid_in.value  = 0
    dut.pixel_in.value  = 0
    dut.weight_in.value = 0
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.rst.value = 0

    dut.valid_in.value = 1
    for i in range(1, 10):
        dut.pixel_in.value  = i
        dut.weight_in.value = i
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")

    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    result   = dut.accum_out.value.to_signed()
    expected = sum(i * i for i in range(1, 10))   # 285
    dut._log.info(f"Representative input: accum_out = {result} (expected {expected})")
    assert result == expected, f"Expected {expected}, got {result}"
