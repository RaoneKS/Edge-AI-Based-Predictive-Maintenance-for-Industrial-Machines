# Edge-AI-Based Predictive Maintenance for Industrial Machines

An FPGA-oriented predictive-maintenance workflow using **bearing vibration only** as the model input. The project combines a compact 1D-CNN, integer quantization, an INT8 matrix-multiplication accelerator, and a DE10-Standard implementation path.

> **Evidence note:** The ML metrics below are recorded in `ml/PHASE3_RESULTS.md` and `ml/artifacts/metrics_and_quantization.json`. FPGA board results are reported separately from model-evaluation results. Items not evidenced by committed reports are marked as pending rather than estimated.

## 1. System overview

```text
Bearing vibration
      |
      v
256-sample windowing and per-window normalization
      |
      v
1D-CNN (four bearing-condition classes)
      |
      v
INT8 weights/activations + INT32 accumulation
      |
      v
8x8 tiled FPGA inference accelerator
      |
      v
Predicted condition
```

The current dataset pipeline uses the **Case Western Reserve University (CWRU) 12 kHz drive-end bearing-vibration recordings**. The four labels are:

1. Normal
2. Inner-race fault
3. Ball fault
4. Outer-race fault

Recordings are split before windowing to avoid placing windows from the same acquisition in both training and test sets. Each inference window contains 256 samples and is normalized using its own mean and standard deviation.

## 2. Neural-network model

The exported model is:

```text
Input vibration window
  -> Conv1D(1, 8, kernel=5)
  -> ReLU
  -> MaxPool1D(2)
  -> Conv1D(8, 8, kernel=3)
  -> ReLU
  -> GlobalAveragePooling1D
  -> Dense(8, 4)
  -> Four class logits
```

### Recorded model results

| Evaluation | Correct / total | Accuracy |
|---|---:|---:|
| FP32 | 473 / 512 | 92.38% |
| Integer-equivalent INT8 | 458 / 512 | 89.45% |

These are **model evaluation** results from the Phase 3 CWRU recording-level holdout. They must not be described as a four-class physical-board demonstration or as a live-sensor end-to-end result.

## 3. Quantized accelerator workload

- Activations and weights: signed INT8
- Accumulation: INT32
- Requantized layer outputs: INT8
- Zero point: 0
- Activation scales are power-of-two scales exported with the model artifacts.

| Layer | Logical K | Physical K | Output channels | Requantization right shift |
|---|---:|---:|---:|---:|
| Conv1 | 5 | 8 | 8 | 8 |
| Conv2 | 24 | 24 | 8 | 8 |
| Classifier | 8 | 8 | 4 logical (8 physical lanes) | 5 |

Conv1 is mapped to 256 one-tile 8x8 operations. Conv2 is mapped to 128 groups of three 8x8 K-tiles, with INT32 partial sums combined before bias, requantization and activation. The classifier uses one padded 8x8 operation. Max pooling and global average pooling are listed in the deployment contract as HPS or board-wrapper operations; do not assume they are performed inside the baseline matrix-multiplication RTL.

See [ml/README.md](ml/README.md), [ml/PHASE3_RESULTS.md](ml/PHASE3_RESULTS.md), and [the quantization manifest](ml/artifacts/metrics_and_quantization.json).

## 4. FPGA accelerator and board evidence

The repository also contains an 8x8 INT8 systolic-array accelerator with tiling, SRAM buffering, INT32 accumulation, requantization, and streaming interfaces. The generic Artix-7 resource table previously shown in this repository describes that accelerator baseline; it is **not** the DE10-Standard/Cyclone V application result and must not be mixed with it.

The project’s recorded DE10-Standard application results from the development work are:

| Item | Recorded result |
|---|---|
| Board / device | Terasic DE10-Standard, Cyclone V 5CSXFC6D6F31C6 |
| Board clock | 50 MHz |
| Post-fit Fmax | 59.01 MHz |
| Worst setup slack | +3.054 ns |
| Hold slack | +0.215 ns |
| DSP usage | 20 / 112 (18%) |
| Registers | 30,766 |
| Quartus errors | 0 |
| Recorded RTL/demo latency | 8,969 cycles |

The recorded physical demonstration covered **Normal (class 0) and Outer (class 3)** using preloaded vibration samples. This is not evidence of live accelerometer streaming or physical-board validation of all four classes. Re-run the current checked-in project and archive the exact Quartus reports, bitstream identity, test logs and board demonstration evidence before treating these values as a fresh reproducibility result.

## 5. What is implemented vs. what remains

### Implemented / recorded

- CWRU vibration-only four-class data pipeline.
- Recording-level holdout and 256-sample window contract.
- Compact 1D-CNN training/export.
- FP32 and integer-equivalent INT8 evaluation.
- Exported INT8 weights, biases and quantization metadata.
- 8x8 tiled accelerator RTL and verification infrastructure.
- DE10-Standard synthesis/timing and selected-condition board demonstration results.

### Not yet evidenced as complete in the repository

- Live accelerometer capture connected to continuous FPGA inference.
- A reproducible four-class physical-board demonstration.
- Per-class precision, recall, F1, confusion matrix and false-alarm analysis.
- Comparison against threshold-based and conventional-ML baselines on the same held-out recordings.
- Measured board power and energy per inference.
- A controlled end-to-end latency breakdown including preprocessing, transfers, pooling/wrapper work and inference.
- A final paper with claims cross-checked against archived artifacts.

The validation plan and claim boundaries are tracked in [docs/VALIDATION_STATUS.md](docs/VALIDATION_STATUS.md).

## 6. Reproducibility

Use the scripts and artifact manifest already present under `ml/` and `verification/`. Before publishing new results:

1. Record the Git commit and dataset file/version identifiers.
2. Re-run the recording-level split and confirm there is no recording leakage.
3. Re-run FP32 and integer-equivalent INT8 inference on the same held-out windows.
4. Save predictions and labels, then calculate confusion matrix, per-class precision/recall/F1 and macro averages.
5. Run identical held-out windows through the threshold and conventional-ML baselines.
6. Run RTL simulation and compare every output against the bit-accurate golden model.
7. Archive Quartus version, device, constraints, fitter/timing/resource reports and programming evidence.
8. Measure board power with a documented instrument and report idle and active power separately; calculate energy only from measured power and measured execution time.

Do not report a metric unless its input set, script, configuration and output artifact are archived.

## 7. Repository map

- `rtl/` — accelerator RTL.
- `tb/` — SystemVerilog testbench.
- `verification/` — golden-model and verification assets.
- `ml/` — CWRU data pipeline, model export and quantization artifacts.

## 8. Scope and limitations

This project currently focuses on **bearing-vibration classification**. It does not establish a complete industrial deployment, live sensor-to-FPGA pipeline, cloud/network comparison, measured energy efficiency, or validated diagnosis of arbitrary machine faults. Those require separate experiments and evidence.

