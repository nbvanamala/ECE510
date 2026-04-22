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
    Runs until the 32-bit signed accumulator actually wraps past 2^31-1,
    then asserts that the design wraps (does NOT saturate).

    Expected wrap-around at cycle ~133,170 (2147483647 // 16129 + 1).
    """
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    dut.rst.value = 1
    dut.a.value   = 0
    dut.b.value   = 0
    await RisingEdge(dut.clk)
    dut.rst.value = 0

    dut.a.value = 127
    dut.b.value = 127
    step        = 127 * 127   # 16129 per cycle
    INT32_MAX   = (1 << 31) - 1

    prev_val = 0
    wrapped  = False

    # Run up to 140 000 cycles — enough to pass the overflow point (~133 170)
    for cycle in range(1, 140_001):
        await RisingEdge(dut.clk)
        cur_val = dut.out.value.signed_integer

        # Detect sign flip: positive → negative means wrap occurred
        if prev_val > 0 and cur_val < 0:
            dut._log.info(
                f"Wrap-around detected at cycle {cycle}: "
                f"{prev_val} → {cur_val}"
            )
            dut._log.info(
                "Behavior: 32-bit signed WRAP-AROUND (does NOT saturate). "
                "No saturation logic present in mac_correct.v — accumulator "
                "rolls over from INT32_MAX to a large negative value."
            )
            wrapped = True
            break

        prev_val = cur_val

    assert wrapped, (
        f"No overflow observed within 140 000 cycles. "
        f"Last value: {prev_val}"
    )
