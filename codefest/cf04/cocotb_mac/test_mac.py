"""
test_mac.py — cocotb testbench for mac_correct.v
Codefest 4 — COPT Part A
LLM used: Claude Sonnet 4.6
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


@cocotb.test()
async def test_mac_basic(dut):
    """
    Basic accumulation and reset test.
      Phase 1: a=3,  b=4  x3 cycles -> out: 12, 24, 36
      Phase 2: assert rst            -> out: 0
      Phase 3: a=-5, b=2  x2 cycles -> out: -10, -20
    """
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    # Apply reset, wait for rising edge, then release after a small delta
    dut.rst.value = 1
    dut.a.value   = 0
    dut.b.value   = 0
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")   # small delta after edge

    # Release reset and set inputs before next rising edge
    dut.rst.value = 0
    dut.a.value   = 3
    dut.b.value   = 4

    # Phase 1: read output AFTER each rising edge
    for expected in [12, 24, 36]:
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        got = dut.out.value.to_signed()
        assert got == expected, f"Expected {expected}, got {got}"
        dut._log.info(f"out = {got}  (expected {expected})  PASS")

    # Phase 2: assert reset
    dut.rst.value = 1
    dut.a.value   = 0
    dut.b.value   = 0
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    got = dut.out.value.to_signed()
    assert got == 0, f"Expected 0 after reset, got {got}"
    dut._log.info(f"After rst: out = {got}  PASS")

    # Phase 3: a=-5, b=2 for 2 cycles
    dut.rst.value = 0
    dut.a.value   = -5 & 0xFF   # 8-bit two's complement for -5
    dut.b.value   = 2
    for expected in [-10, -20]:
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        got = dut.out.value.to_signed()
        assert got == expected, f"Expected {expected}, got {got}"
        dut._log.info(f"out = {got}  (expected {expected})  PASS")


@cocotb.test()
async def test_mac_overflow(dut):
    """
    Overflow test: accumulate with a=127, b=127 (+16129 per cycle).
    Runs until the 32-bit signed accumulator wraps past 2^31-1,
    then asserts that the design wraps (does NOT saturate).

    Expected wrap-around at cycle ~133146.
    """
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    dut.rst.value = 1
    dut.a.value   = 0
    dut.b.value   = 0
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.rst.value = 0
    dut.a.value   = 127
    dut.b.value   = 127

    prev_val = 0
    wrapped  = False

    for cycle in range(1, 140_001):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        cur_val = dut.out.value.to_signed()

        if prev_val > 0 and cur_val < 0:
            dut._log.info(
                f"Wrap-around detected at cycle {cycle}: "
                f"{prev_val} -> {cur_val}"
            )
            dut._log.info(
                "Behavior: 32-bit signed WRAP-AROUND (does NOT saturate). "
                "No saturation logic present in mac_correct.v -- accumulator "
                "rolls over past INT32_MAX to a large negative value."
            )
            wrapped = True
            break

        prev_val = cur_val

    assert wrapped, (
        f"No overflow observed within 140000 cycles. "
        f"Last value: {prev_val}"
    )
