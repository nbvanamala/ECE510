# ResNet-18 Profiling Analysis

## Top 5 Layers by MAC Count

| Layer Name     | MACs         | Parameters |
|----------------|-------------|-----------|
| Conv2d: 1-1    | 118,013,952 | 9,408     |
| Conv2d: 3-1    | 115,605,504 | 36,864    |
| Conv2d: 3-4    | 115,605,504 | 36,864    |
| Conv2d: 3-16   | 115,605,504 | 147,456   |
| Conv2d: 3-29   | 115,605,504 | 589,824   |

---

## Arithmetic Intensity Calculation for the Highest MAC Layer (Conv2d:1-1)

**Step 1: Compute FLOPs**  
FLOPs are 2×MACs:
FLOPs = 2 × 118,013,952 = 236,027,904

**Step 2: Compute Memory Access (No Reuse)**  

- Weights: 9,408 × 4 bytes = 37,632 bytes  
- Input activations: 3 × 224 × 224 × 4 = 602,112 bytes  
- Output activations: 64 × 112 × 112 × 4 = 3,211,264 bytes  
Total memory = 37,632 + 602,112 + 3,211,264 = 3,851,008 bytes


**Step 3: Arithmetic Intensity (FLOPs per byte)**  
Arithmetic Intensity (AI) = FLOPs / Total Memory
AI = 236,027,904 / 3,851,008 ≈ 61.28 FLOPs/byte
