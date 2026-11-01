# Research Claims and Technical Contributions
## Edge-AI-Based Predictive Maintenance for Industrial Machines

**Project:** Edge-AI-Based Predictive Maintenance for Industrial Machines
**Target Platform:** Terasic DE10-Standard (Intel Cyclone V SoC `5CSXFC6D6F31C6`)
**Evaluation Standard:** Rigorous Experimental Proof & Verifiable Evidence

---

## 1. Verified Technical Claims (Backed by Direct Evidence)

### Claim 1: Exact Bit-Level Hardware/Software Equivalence for INT8 1D-CNN
- **Description:** An INT8 systolic accelerator architecture achieves 100% bit-accurate numerical equivalence with a mathematically defined golden model across all intermediate tensors (Conv1, MaxPool, Conv2, GAP) and final classification logits.
- **Evidence:** Over 512 held-out windows ($131,072$ vibration samples), RTL simulation matched all $2,048$ output logits bit-for-bit with zero divergence (`sim/acceptance_logs/cnn_512.log`). All 50 error cases match the exact same sample indices.

### Claim 2: Zero-Overhead Multi-Tile INT32 Accumulation for Extended Kernel Channels
- **Description:** For Conv2 with logical dimension $K = 24$ (spanning 8 input channels $\times$ kernel size 3), a spatial $8\times 8$ systolic array evaluates the tensor across three sequential $K=8$ sub-tiles, preserving 32-bit partial sums in hardware accumulators prior to bias injection and requantization.
- **Evidence:** First-32 intermediate tensor verification demonstrated $32,768$ identical Conv2 output bytes against the software golden model, with zero intermediate precision loss.

### Claim 3: Power-of-Two Requantization with Arithmetic Right Shift and Asymmetric Saturation
- **Description:** Hardware requantization converts 32-bit accumulators directly to 8-bit signed activations using arithmetic right shifts and $[-128, +127]$ saturation without costly division or floating-point multipliers.
- **Evidence:** Demonstrated across 512 test windows and verified in `verification/results/quantization_contract_audit.json`. Requantization right shifts: Conv1 = 8, Conv2 = 8, Classifier = 5.

### Claim 4: Deterministic Real-Time Inference Latency on Industrial FPGAs
- **Description:** The dedicated systolic CNN inference pipeline delivers completely deterministic latency of 15,129 clock cycles per 256-sample vibration window.
- **Evidence:** Min, max, and average cycles are identical ($15,129$ cycles = $302.58\text{ }\mu\text{s}$ at $50\text{ MHz}$). At $12\text{ kHz}$ sampling, a 256-sample window arrives every $21.33\text{ ms}$, yielding an edge computation-to-acquisition ratio of:
  $$\frac{0.30258\text{ ms}}{21.33\text{ ms}} = 1.42\% \text{ duty cycle},$$
  leaving $98.58\%$ of processing time available for power gating, multi-channel aggregation, or supervisory tasks.

### Claim 5: Fully Constrained 50 MHz Timing Closure on Intel Cyclone V SoC
- **Description:** The full top-level accelerator design synthesizes, fits, and timing-closes at 50 MHz on low-cost Cyclone V logic (`5CSXFC6D6F31C6`).
- **Evidence:** TimeQuest STA reports positive setup slack of $+2.143\text{ ns}$ (Slow 85°C model), hold slack of $+0.118\text{ ns}$, 0 unconstrained paths, and an $F_{\text{max}}$ of $56.0\text{ MHz}$ (`quartus/de10_systolic_cnn/output_files/sta_reports/`).

---

## 2. Unverified Claims & Future Work (Explicitly Disclosed)

To maintain absolute academic integrity, the following capabilities are **explicitly noted as unverified or ongoing research**:

| Topic | Current Status | Required Future Work |
|---|---|---|
| **Continuous Live Accelerometer Streaming** | **UNVERIFIED / PENDING** | Requires SPI/I2C streaming driver on HPS or soft-core pulling live accelerometer data directly into FPGA BRAM. |
| **512-Window Physical On-Board Accuracy** | **NOT MEASURED** | Offline simulation proven; physical board demonstration verified on preloaded Normal/Outer samples, but full 512-window automated physical testbench remains to be executed. |
| **Direct Power & Energy Consumption** | **ESTIMATED ONLY** | Power measurement requires physical current-shunt instrumentation across the DE10-Standard 5V/12V rails during continuous inference. |
| **Upstream CWRU Load Independence** | **DISCLOSED LIMITATION** | Software split code enforces file-level separation, but upstream motor load conditions were not independently randomized. |
| **Multi-Sensor Fusion (Acoustic / Temp)** | **EXCLUDED BY DESIGN** | The model strictly processes vibration data to meet the professor's vibration-only predictive maintenance mandate. |

---

## 3. Mathematical Formulation of the Edge-AI Pipeline

### 3.1 Preprocessing and Window Normalization
For a discrete vibration sequence $s[n]$ sampled at $f_s = 12\text{ kHz}$, a window of length $W = 256$ is extracted:
$$\mathbf{x} = [s[0], s[1], \dots, s[W-1]]^T.$$
Per-window normalization is applied:
$$\tilde{x}_i = \frac{x_i - \mu}{\sigma + \epsilon}, \quad \text{where } \mu = \frac{1}{W} \sum_{i=0}^{W-1} x_i, \quad \sigma = \sqrt{\frac{1}{W} \sum_{i=0}^{W-1} (x_i - \mu)^2}.$$

### 3.2 Fixed-Point INT8 Quantization
Normalized floating-point activations are scaled into 8-bit signed integers:
$$x_{\text{int8}} = \text{clamp}\left( \left\lfloor \frac{\tilde{x}}{S_{\text{in}}} \right\rceil, -128, 127 \right), \quad S_{\text{in}} = 2^{-4} = 0.0625.$$

### 3.3 Systolic Array Multiply-Accumulate (MAC)
Each Processing Element (PE) performs signed integer multiply-accumulate:
$$\text{acc}[t] = \text{acc}[t-1] + \left( x_{\text{int8}}[t] \times w_{\text{int8}}[t] \right),$$
where $x_{\text{int8}}, w_{\text{int8}} \in [-128, 127]$ and $\text{acc} \in [-2^{31}, 2^{31}-1]$ (32-bit signed accumulator).

### 3.4 Hardware Requantization & Activation
Before transferring to the next layer:
$$\tilde{y} = \text{acc} + b_{\text{int32}},$$
$$y_{\text{relu}} = \begin{cases} \max(0, \tilde{y}) & \text{if ReLU enabled} \\ \tilde{y} & \text{otherwise} \end{cases}$$
$$y_{\text{int8}} = \text{clamp}\left( y_{\text{relu}} \gg S_{\text{shift}}, -128, 127 \right).$$
For Conv1, $S_{\text{shift}} = 8$; for Conv2, $S_{\text{shift}} = 8$; for the Classifier, $S_{\text{shift}} = 5$.
