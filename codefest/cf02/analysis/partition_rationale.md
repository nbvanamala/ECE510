# HW/SW Partition Proposal
## ECE510 Codefest 2 | Naveen Babu Vanamala | Spring 2026

## (a) Which Kernel to Accelerate in Hardware and Why
The roofline analysis identifies Conv2D forward pass as the dominant kernel,
consuming 80.6% of total runtime. With an arithmetic intensity of 2.51 FLOP/byte
and a CPU ridge point of 2.75 FLOP/byte, the kernel sits just below the ridge
and is memory-bound on the CPU. This makes it ideal for hardware acceleration.
A custom accelerator with larger on-chip SRAM buffers and dedicated convolution
engines can exploit data reuse across the kernel window, raising the operational
arithmetic intensity well above the ridge point. Instead of reloading input patches
from DRAM for each output position, a hardware accelerator can cache the input
feature map tile on-chip and stream the weights, drastically reducing DRAM traffic.

## (b) What the Software Baseline Will Continue to Handle
The software layer will manage data loading, preprocessing, training loop control,
epoch iteration, learning rate scheduling, loss computation, the backward pass,
pooling layers, fully connected layers, and activation functions such as ReLU.
These components account for less than 20% of total runtime and involve control
flow that is difficult to pipeline efficiently in hardware. The host CPU will
orchestrate data transfer to and from the accelerator and manage the interface.

## (c) Interface Bandwidth Required
With a target of 500 GFLOP/s and arithmetic intensity of 2.51 FLOP/byte:
Required BW = 500 / 2.51 = 199 GB/s
This exceeds PCIe 4.0 x16 bandwidth (~32 GB/s), so on-chip SRAM buffering
is essential. The accelerator must buffer entire input tiles locally and minimize
DRAM round-trips. A tile size of 64x64 with double-buffering is planned.

## (d) Bound Classification and Accelerator Impact
On the CPU, Conv2D is memory-bound (AI=2.51 < ridge=2.75 FLOP/byte).
The hardware accelerator targets AI of 8-12 FLOP/byte through on-chip SRAM
reuse and fixed-point arithmetic (INT8/INT16), pushing the kernel into the
compute-bound regime. Performance will then scale with peak FLOP/s rather
than memory bandwidth, which is the target for edge CNN inference.
