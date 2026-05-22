Name: Naveen Babu Vanamala

Course: Hardware for Artificial Intelligence and Machine Learning

Term: Spring 2026

Tentative Project Topic:
Edge CNN Accelerator for Industrial AI Applications

For my project, I plan to create a hardware accelerator that makes Convolutional Neural Networks (CNNs) run faster on small devices like industrial sensors or cameras. CNNs are commonly used in AI for tasks such as image recognition, detecting defects, and monitoring equipment. My design will use fixed point arithmetic and multiple convolution units working in parallel, which allows it to process data quickly while using less energy. I will implement the design in SystemVerilog and test it using Icarus Verilog and QuestaSim to make sure it works correctly. This project will show a practical way to run AI tasks efficiently on small devices, without needing to build a physical chip.

---

## HDL Compute Core (Milestone 2 — in progress)

### Module: `conv_pe` (Convolution Processing Element)
**File:** `project/hdl/conv_pe.sv`

`conv_pe` is a parameterized, synthesizable SystemVerilog module implementing a single convolution Processing Element for the Edge CNN Accelerator. It accepts a stream of INT8-signed pixel and weight pairs via a `valid_in` handshake, accumulates `pixel × weight` products into a 32-bit signed register over one kernel window (`KERNEL_SIZE` taps, default 9 for a 3×3 kernel), and pulses `valid_out` with the completed dot-product on the final tap. Parameters allow scaling to different kernel sizes and data widths without RTL changes.

**Testbench:** `project/hdl/test_conv_pe.py` (cocotb)

### Interface Choice: AXI4
The accelerator exposes an AXI4 on-chip bus interface between the host CPU and the convolution PE array. AXI4 supports high-throughput burst transfers that match the tiled memory access pattern of the convolution engine.

### Precision: INT8
Weights and activations use INT8 symmetric quantization (scale factor S = max|W| / 127, as derived in CF04 CMAN). INT8 arithmetic halves DRAM bandwidth versus FP16 and is natively supported by the MAC array.

### Interface Bandwidth Justification
From the M1 roofline analysis, the convolution kernel has an arithmetic intensity of **2.51 FLOP/byte** and the target throughput is **500 GFLOP/s**, requiring ~199 GB/s of effective bandwidth. A naive CPU-to-accelerator link (PCIe 4.0 x16, ~32 GB/s) would be ~6× too slow. The design therefore uses AXI4 with large on-chip SRAM tile buffers (2 MB scratchpad + 512 KB weight buffer) to keep most data movement on-chip, reducing the external bandwidth requirement to ~32 GB/s — within reach of PCIe 4.0 x16 with double-buffered tiling. This matches the interface analysis documented in `project/m1/interface_selection.md`.
