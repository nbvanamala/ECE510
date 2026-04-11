# Software Baseline
## ECE510 M1 | Naveen Babu Vanamala | Spring 2026
## Project: Edge CNN Accelerator for Industrial AI Applications

---

## 1. Algorithm Description
The software baseline is a CNN with manual backpropagation implemented in
pure NumPy/Python (cnn_backprop). It performs image classification tasks
such as defect detection on industrial sensor data. The network consists
of convolutional layers, ReLU activations, max pooling, and fully connected
layers trained with stochastic gradient descent.

## 2. Baseline Performance (Measured)
- Hardware: Intel Core i7-1165G7, 4 cores @ 2.80 GHz
- Memory: LPDDR4x, 51.2 GB/s bandwidth
- Total runtime (3 epochs, synthetic data): 38.72 seconds
- Dominant kernel: Conv2D._im2col = 80.6% of runtime (31.2 of 38.7 seconds)
- Arithmetic Intensity: 2.51 FLOP/byte
- Attainable throughput: ~128.5 GFLOP/s
- Bound classification: Memory-bound (AI < ridge point 2.75 FLOP/byte)

## 3. Bottleneck Analysis
The im2col transformation constructs a column matrix from the input feature
map before matrix multiplication. It uses nested Python loops over output
spatial positions (H_out x W_out), causing:
- Repeated DRAM loads of input patches with no reuse
- Low arithmetic intensity (2.51 FLOP/byte)
- CPU underutilization due to memory stalls

## 4. Limitations of Software Baseline
- Cannot meet real-time inference requirements for industrial edge deployment
- General-purpose CPU lacks dedicated convolution hardware
- Python loop overhead adds significant latency beyond memory bottleneck
- Power consumption of CPU (~28W TDP) too high for edge IoT devices
- No parallelism across output channels during convolution

## 5. Benchmark Results Summary
| Metric              | Value         |
|---------------------|---------------|
| Total runtime       | 38.72 s       |
| Conv2D time         | 31.20 s       |
| Arithmetic Intensity| 2.51 FLOP/B   |
| Throughput          | 128.5 GFLOP/s |
| Bound               | Memory-bound  |
| Power (CPU TDP)     | 28 W          |
