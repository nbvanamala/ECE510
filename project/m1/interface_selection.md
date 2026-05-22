# Interface Selection and Bandwidth Analysis
## ECE510 M1 | Naveen Babu Vanamala | Spring 2026
## Project: Edge CNN Accelerator for Industrial AI Applications

---

## 1. Interface Choice
The selected interface between the host CPU and the CNN accelerator chiplet
is AXI4 (Advanced eXtensible Interface 4), a widely used industry-standard
on-chip bus protocol from ARM AMBA. AXI4 supports high-throughput burst
transfers, separate read and write channels, and is compatible with most
FPGA and ASIC design flows including those supported by common SystemVerilog
toolchains.

## 2. Bandwidth Requirement Analysis
From the roofline analysis in Codefest 2:
- Target accelerator throughput: 500 GFLOP/s
- Dominant kernel arithmetic intensity: 2.51 FLOP/byte
- Required interface bandwidth = 500 / 2.51 = 199 GB/s

This exceeds standard PCIe 4.0 x16 bandwidth (~32 GB/s), confirming that
a naive CPU-to-accelerator interface would become a bottleneck. Therefore
the design relies on large on-chip SRAM tile buffers to minimize off-chip
data movement.

## 3. On-Chip Buffer Strategy
To avoid interface bottleneck:
- 2 MB on-chip SRAM scratchpad for input feature map tiles
- Double buffering: load next tile while processing current tile
- Tile size: 64x64 spatial with full channel depth
- Weight buffers: 512 KB for kernel weights (reused across batch)
- With tiling, effective off-chip bandwidth requirement drops to ~32 GB/s
  which is achievable with PCIe 4.0 x16 or HBM2 interface

## 4. Interface Bandwidth Summary
| Interface Option    | Bandwidth    | Feasible?       |
|---------------------|--------------|-----------------|
| PCIe 3.0 x16        | ~16 GB/s     | No (too slow)   |
| PCIe 4.0 x16        | ~32 GB/s     | Yes (with tiling)|
| HBM2                | ~256 GB/s    | Yes (ideal)     |
| On-chip AXI4 + SRAM | ~200+ GB/s   | Yes (proposed)  |

## 5. Conclusion
The proposed interface uses AXI4 with on-chip SRAM tiling to meet the
bandwidth requirement of 199 GB/s internally, while keeping the external
interface requirement at ~32 GB/s — achievable with PCIe 4.0 x16.
This avoids the accelerator becoming interface-bound at target throughput.
