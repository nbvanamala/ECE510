# Makefile — cocotb simulation for crossbar_mac.sv
# Usage: make SIM=icarus   (requires iverilog installed)
# Fallback: python crossbar_sim.py  (behavioral, no simulator needed)

SIM             = icarus
TOPLEVEL_LANG   = systemverilog
VERILOG_SOURCES = $(PWD)/crossbar_mac.sv
TOPLEVEL        = crossbar_mac
MODULE          = crossbar_tb

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: sim_py
sim_py:
	python crossbar_sim.py
