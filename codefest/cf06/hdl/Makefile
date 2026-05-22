# Makefile — iverilog simulation for crossbar_mac.sv / crossbar_tb.sv
# Usage: make        (compile + simulate)
#        make clean  (remove build artifacts)

SV_FILES = crossbar_mac.sv crossbar_tb.sv
SIM_BIN  = crossbar_sim

.PHONY: all sim clean

all: sim

$(SIM_BIN): $(SV_FILES)
	iverilog -g2012 -o $(SIM_BIN) $(SV_FILES)

sim: $(SIM_BIN)
	vvp $(SIM_BIN) | tee sim_log.txt

clean:
	rm -f $(SIM_BIN) crossbar_tb.vcd sim_log.txt
