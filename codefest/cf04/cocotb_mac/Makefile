# Makefile — cocotb simulation for mac_correct.v
# Codefest 4 — COPT Part A
# Usage: make SIM=icarus

SIM             = icarus
TOPLEVEL_LANG   = verilog
VERILOG_SOURCES = $(PWD)/../hdl/mac_correct.v
TOPLEVEL        = mac
MODULE          = test_mac

include $(shell cocotb-config --makefiles)/Makefile.sim
