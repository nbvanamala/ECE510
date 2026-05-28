# CMAN — Arithmetic Intensity of Project Kernel
## CF09 | ECE510 Spring 2026 | Naveen Babu Vanamala

> **NO AI — all calculations below are hand-derived.**

---

## Task 1 — Dominant Kernel

**Kernel name:**

**Dimensions:**

**Data types:**

---

## Task 2 — FLOPs Count

**Formula:**

**Substituted values:**

**Total FLOPs per invocation:**

---

## Task 3 — Bytes Transferred

### Lower bound — no data reuse

**Formula:**

**Values:**

**Total bytes (no reuse):**

### Upper bound — full on-chip weight reuse

**Reuse pattern name:**

**Formula:**

**Values:**

**Total bytes (full reuse):**

---

## Task 4 — Arithmetic Intensity

| Bound        | FLOPs | Bytes | AI (FLOPs/byte) |
|--------------|-------|-------|-----------------|
| Lower (no reuse) |  |  |  |
| Upper (full reuse) |  |  |  |

**Hand-drawn roofline sketch:** `codefest/cf09/cman_roofline_sketch.pdf`

---

## Task 5 — Bottleneck and Improvement

**Current bottleneck** (circle one): hardware interface BW / on-chip memory BW / compute units

**Single highest-leverage change:**
