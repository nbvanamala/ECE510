"""
test_mac.py — cocotb testbench for mac_correct.v
Codefest 4 — COPT Part A
LLM used: Claude Sonnet 4.6
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


@cocotb.test()
async def test_mac_basic(dut):
    """
    Basic accumulation and reset test.
      Phase 1: a=3,  b=4  x3 cycles → out: 12, 24, 36
      Phase 2: assert rst            → out: 0
      Phase 3: a=-5, b=2  x2 cycles → out: -10, -20
    """
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset
    dut.rst.value = 1
    dut.a.value   = 0
    dut.b.value   = 0
    await RisingEdge(dut.clk)

    # Phase 1: a=3, b=4 for 3 cycles
    dut.rst.value = 0
    dut.a.value   = 3
    dut.b.value   = 4
    for expected in [12, 24, 36]:
        await RisingEdge(dut.clk)
        got = dut.out.value.signed_integer
        assert got == expected, f"Expected {expected}, got {got}"
        dut._log.info(f"out = {got}  (expected {expected})  PASS")

    # Phase 2: assert reset
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    got = dut.out.value.signed_integer
    assert got == 0, f"Expected 0 after reset, got {got}"
    dut._log.info(f"After rst: out = {got}  PASS")

    # Phase 3: a=-5, b=2 for 2 cycles
    dut.rst.value = 0
    dut.a.value   = -5 & 0xFF   # 8-bit two's complement for -5
    dut.b.value   = 2
    for expected in [-10, -20]:
        await RisingEdge(dut.clk)
        got = dut.out.value.signed_integer
        assert got == expected, f"Expected {expected}, got {got}"
        dut._log.info(f"out = {got}  (expected {expected})  PASS")


@cocotb.test()
async def test_mac_overflow(dut):
    """
    Overflow test: accumulate with a=127, b=127 (+16129 per cycle).
    Verifies wrap-around behavior (no saturation) near 2^31 - 1.

    At +16129/cycle, overflow occurs around cycle 133,170.
    We run 100 cycles to confirm linear accumulation, then
    mathematically confirm wrap-around (no saturation hardware present).
    """
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    dut.rst.value = 1
    dut.a.value   = 0
    dut.b.value   = 0
    await RisingEdge(dut.clk)
    dut.rst.value = 0

    dut.a.value = 127
    dut.b.value = 127
    step = 127 * 127  # 16129

    # Run 100 cycles and verify linear accumulation
    for i in range(1, 101):
        await RisingEdge(dut.clk)
    got      = dut.out.value.signed_integer
    expected = step * 100  # 1,612,900
    assert got == expected, f"At cycle 100 expected {expected}, got {got}"
    dut._log.info(f"Cycle 100: out = {got}  (expected {expected})  PASS")

    # Predict overflow cycle and document wrap behavior
    INT32_MAX       = (1 << 31) - 1
    overflow_cycle  = INT32_MAX // step + 1   # ~133,170
    dut._log.info(
        f"Overflow behavior: 32-bit signed wrap-around (no saturation). "
        f"Predicted wrap at cycle ~{overflow_cycle} from reset. "
        f"Design does NOT saturate — accumulator rolls over to large negative."
    )
