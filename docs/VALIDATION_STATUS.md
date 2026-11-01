# Validation status and completion checklist

This document separates committed evidence from work that still needs an executable experiment. It is intentionally conservative: no missing metric is inferred or fabricated.

## Evidence currently recorded

| Area | Evidence | Status |
|---|---|---|
| Dataset | CWRU 12 kHz drive-end vibration; four labels; recording-level holdout; 256-sample windows | Recorded in `ml/artifacts/metrics_and_quantization.json` |
| FP32 model | 473/512 correct (92.3828%) | Recorded |
| Integer-equivalent INT8 model | 458/512 correct (89.4531%) | Recorded |
| Network | Conv1D(1,8,k=5), ReLU, MaxPool1D(2), Conv1D(8,8,k=3), ReLU, GAP, Dense(8,4) | Recorded |
| Quantization | INT8 operands/outputs, INT32 accumulation, scales and shifts in manifest | Recorded |
| Accelerator | 8x8 tiled INT8 systolic-array baseline and verification assets | Present in repository |
| DE10 implementation | Fmax 59.01 MHz, setup slack +3.054 ns, hold +0.215 ns, DSP 20/112, 30,766 registers | Previously recorded development result; archive/re-run reports for reproducibility |
| Physical demo | Normal and Outer using preloaded samples; 8,969-cycle recorded latency | Previously recorded development result; not live sensor streaming |

## Outstanding experiments

### A. Per-class classification metrics

**Required:** confusion matrix, precision, recall, F1 and support for Normal, Inner, Ball and Outer; macro and weighted averages.

**Procedure:** run the exported FP32 and integer-equivalent INT8 models over the exact held-out set, save one row per sample containing recording ID, true label, predicted label and model variant, then calculate metrics from those saved predictions.

**Acceptance:** the 512-sample denominator and class supports must reconcile with the saved prediction file. Keep recording IDs in the output so the split can be audited. Do not calculate metrics from rounded accuracy alone.

### B. Baseline comparisons

Evaluate all methods on the **same recording-level held-out partition**:

1. A vibration-amplitude threshold baseline. Define the statistic, threshold-selection procedure and tuning split before evaluation.
2. At least one conventional ML baseline (for example, an SVM or random forest) using explicitly documented vibration-window features.
3. FP32 CNN.
4. Integer-equivalent INT8 CNN.

Report confusion matrices and macro-F1 alongside accuracy. Thresholds and model hyperparameters must be selected without using the held-out test labels.

### C. Live vibration acquisition

The existing model contract accepts normalized 256-sample vibration windows. To claim live sensor inference, demonstrate the full chain:

sensor sampling -> timestamped samples -> window assembly -> normalization -> quantization -> transfer to inference engine -> class output.

Archive sensor identity, sample rate, calibration/units, dropped-sample count, window overlap, transfer protocol and end-to-end latency. A serial capture script or sensor read alone is not evidence of FPGA-connected live inference.

### D. Hardware reproducibility

Archive:

- Quartus version and exact FPGA part.
- Top-level project revision and constraints.
- Full synthesis/fitter/timing/resource reports.
- Bitstream checksum and programming log.
- RTL test logs and golden-model comparison.
- Board demonstration input vectors and observed outputs.

The previously recorded DE10 results are historical project evidence until reproduced from the exact commit being submitted.

### E. Power and energy

Do not use generic board estimates or FPGA resource counts as measured power. Measure board input power with a documented instrument and state voltage/current measurement points, sampling rate, idle baseline, active workload and repeat count. Report mean and variation. Energy per inference must use measured active energy over a clearly defined inference interval; subtract idle power only if the methodology is stated.

### F. Latency

Separate preprocessing/windowing, host-to-FPGA transfer, accelerator execution, postprocessing and total sensor-to-result latency. State clock frequency and cycle count. The recorded 8,969 cycles must be tied to the exact measured path; do not convert it to wall-clock latency without confirming the relevant clock and scope.

### G. Paper and presentation

The final manuscript should distinguish:
- offline model accuracy,
- integer-equivalent quantized model accuracy,
- RTL simulation correctness,
- FPGA implementation timing/resources,
- physical-board demonstration,
- live sensor integration (only if completed).

Do not claim four-class physical-board validation, live streaming, measured power savings, cloud superiority or energy efficiency unless corresponding artifacts are included.

## Submission gate

The project is ready for a defensible research submission when every reported number points to a reproducible artifact, all comparisons use the same held-out partition, and limitations are explicit. The remaining hardware experiments require the user's local Quartus environment and physical DE10/sensor; GitHub documentation edits cannot perform those measurements.
