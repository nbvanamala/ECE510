# Updated Heilmeier Catechism — Edge CNN Accelerator for Industrial AI

## Q1: What are you trying to do?

Design and verify a hardware accelerator in SystemVerilog that accelerates the
cnn_backprop algorithm — specifically the Conv2D._im2col kernel — for CNN inference
on edge devices such as industrial cameras, sensors, and embedded controllers, without
relying on cloud offload or a physical chip. The accelerator will use fixed-point
arithmetic and a parallel systolic array of MAC units to achieve significantly higher
throughput-per-watt than a general-purpose CPU. Correctness will be validated through
simulation in Icarus Verilog and QuestaSim against a NumPy software reference.

## Q2: How is it done today, and what are the limits of the current approach?

cProfile profiling of cnn_backprop across 10 runs on an Intel Core i7-1165G7 shows
that Conv2D._im2col (cnn.py:134) dominates execution: 31.204 s out of 38.724 s total
(80.6%), called 930 times across 30 epochs. The remaining kernels — _conv_forward
(5.861 s), backward (3.219 s), and _col2im (2.418 s) — are all secondary. The limits
are: (1) Python nested loops over output spatial positions make per-call overhead
disproportionate to arithmetic work; (2) all operands are streamed from DRAM on every
call with no data reuse; (3) convolutions are computed sequentially with no spatial
parallelism.

## Q3: What is your approach, and why is it better?

Roofline analysis places Conv2D._im2col at an arithmetic intensity of 2.48 FLOP/byte,
well left of the ridge point, confirming it is deeply memory-bound on the current CPU.
The proposed accelerator replaces this kernel with a weight-stationary systolic array
in SystemVerilog, loading weights once into on-chip SRAM and reusing them across all
output spatial positions. This raises the effective arithmetic intensity to approximately
50 FLOP/byte, crossing the ridge point and moving the kernel into the compute-bound
regime. Fixed-point (INT8/INT16) arithmetic replaces FP64, reducing memory footprint
by 4-8x and enabling denser MAC parallelism. The roofline gap between 2.48 and
50 FLOP/byte directly quantifies the performance headroom the accelerator is designed
to capture.

................................................................................................

**Project: Edge CNN Accelerator for Industrial AI Applications**

**Question 1: What are you trying to do?**

I am designing a hardware accelerator for Convolutional Neural Networks (CNNs) tailored for edge devices used in industrial settings. The goal is to enable fast, efficient AI processing on small devices such as cameras or sensors, allowing tasks like defect detection, image recognition, and equipment monitoring to be performed locally without relying on large servers or cloud computing.

**Question 2: How is it done today, and what are the limits of current practice?**

Currently, CNNs are primarily executed on high performance GPUs or cloud servers. While this provides strong computational power, it is unsuitable for edge deployment due to high energy consumption, latency, and hardware size. Existing edge AI solutions are either limited in performance or require simplifications to the models, reducing accuracy and efficiency in real world industrial environments.

**Question 3: What is new in your approach and why do you think it will be successful?**

My approach introduces a custom, parallelized hardware accelerator using fixed point arithmetic to optimize both speed and energy efficiency. Implemented in SystemVerilog and validated through Icarus Verilog and QuestaSim simulations, this design provides a practical method for high performance CNN execution on resource constrained edge devices. By focusing on both architectural efficiency and correctness verification, I believe this solution can bridge the gap between high performance AI and practical industrial deployment.
