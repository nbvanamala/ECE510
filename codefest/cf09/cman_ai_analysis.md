# CMAN — Arithmetic Intensity of Project Kernel
## CF09 | ECE510 Spring 2026 | Naveen Babu Vanamala

> **NO AI — all calculations below are hand-derived.**

---

## Task 1 — Dominant Kernel

**Kernel name:** Conv2D weight-stationary dot product (im2col convolution, `Conv2D._im2col`)

**Dimensions:**
- Input channels: 1 (single channel, broadcast to all PEs)
- Kernel spatial size: 3×3 = 9 taps (KERNEL_SIZE = 9)
- Output channels: 4 (NUM_PE = 4 Processing Elements)
- Input feature map: 32×32 pixels
- Output spatial: H_out = W_out = 30 → 900 output patches per image

**Data types:**
- Weights: INT8 signed (8-bit, 1 byte per value)
- Pixels: INT8 signed (8-bit, 1 byte per value)
- Accumulator: INT32 signed (32-bit, prevents overflow: max = 9 × 127² = 145,161)

---

## Task 2 — FLOPs Count

**Formula:**

    FLOPs = KERNEL_SIZE × NUM_PE × 2 FLOPs/MAC × total_patches

Each MAC (multiply-accumulate) = 1 multiply + 1 add = 2 FLOPs.
All 4 PEs run in parallel, each accumulating over all 9 taps per patch.

**Substituted values:**

    FLOPs = 9 × 4 × 2 × 900
          = 72 FLOPs/patch × 900 patches

**Total FLOPs per invocation:** **64,800 FLOPs**

---

## Task 3 — Bytes Transferred

### Lower bound — no data reuse

**Formula:**

    Bytes_lower = (pixels_per_patch + weights_per_patch) × total_patches
                = (KERNEL_SIZE + NUM_PE × KERNEL_SIZE) × 900

**Values:**

    pixels_per_patch  = 9 pixels × 1 byte each = 9 bytes
    weights_per_patch = 4 PEs × 9 weights × 1 byte each = 36 bytes
    bytes_per_patch   = 9 + 36 = 45 bytes

    Bytes_lower = 45 × 900

**Total bytes (no reuse):** **40,500 bytes**

### Upper bound — full on-chip weight reuse

**Reuse pattern name:** Weight-stationary

The 4 PE weights (36 bytes total) are loaded once into on-chip registers
at the start of an image and held fixed for all 900 patches.
Only pixel bytes stream from off-chip memory on every patch.

**Formula:**

    Bytes_upper = (NUM_PE × KERNEL_SIZE) + (KERNEL_SIZE × total_patches)
                = weights loaded once     +  pixels streamed per image

**Values:**

    weights once  = 4 × 9 × 1 byte = 36 bytes
    pixels total  = 9 × 900 patches = 8,100 bytes

    Bytes_upper = 36 + 8,100

**Total bytes (full reuse):** **8,136 bytes**

---

## Task 4 — Arithmetic Intensity

    AI = Total FLOPs / Total Bytes

| Bound              | FLOPs  | Bytes  | AI (FLOPs/byte) |
|--------------------|--------|--------|-----------------|
| Lower (no reuse)   | 64,800 | 40,500 | **1.60**        |
| Upper (full reuse) | 64,800 |  8,136 | **7.96**        |

**sky130A platform figures (100 MHz, used for roofline sketch):**
- Peak compute = 4 PEs × 1 MAC/cycle × 100 MHz × 2 FLOPs/MAC = **800 MOPS**
- Peak memory bandwidth = **0.33 GB/s** (AXI4-Lite, 32-bit bus, effective)
- Ridge point = 800 MOPS / 330 MB/s = **2.42 FLOP/byte**

**M1 software baseline (for comparison on same plot):**
- SW throughput: 5.91 MFLOPs/s at AI = 2.48 FLOP/byte (measured, re-run)
- HW throughput: 60.0 MFLOPs/s at AI = 2.48 FLOP/byte (measured, cosim)

The lower AI bound (1.60) is left of the ridge → memory-bound with no reuse.
The upper AI bound (7.96) is right of the ridge → compute-bound with full weight reuse.

**Hand-drawn roofline sketch:** `codefest/cf09/cman_roofline_sketch.pdf`

---

## Task 5 — Bottleneck and Improvement

**Current bottleneck** (circle one): **hardware interface BW** / on-chip memory BW / compute units

The measured co-simulation throughput is 60 MFLOPs/s. The sky130A BW ceiling
at AI = 2.48 would give 0.33 GB/s × 2.48 = 819 MFLOPs/s. The design is 13×
below that ceiling. Looking at the simulation timing: one patch invocation
takes 120 clock cycles, of which only 9 cycles are actual MAC accumulation
(7.5% utilization). The other 111 cycles are AXI4-Lite bus protocol overhead:
4 weight writes + 9 pixel writes, each requiring 3 bus phases (address, data,
response). The MAC units are idle waiting for data — this is an interface
bandwidth problem.

**Single highest-leverage change:**

Replace the per-patch sequential AXI4-Lite pixel write loop with a burst or
streaming pixel interface (e.g., a 9-deep FIFO). This collapses pixel delivery
from 27 AXI cycles (9 transactions × 3 phases) down to ~9 FIFO-write cycles,
reducing per-patch latency from 120 cycles to ~30 cycles and raising throughput
from 60 MFLOPs/s to ~240 MFLOPs/s. No changes to the MAC array or synthesis
are required.
