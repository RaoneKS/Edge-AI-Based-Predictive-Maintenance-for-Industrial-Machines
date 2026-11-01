AUTHORITATIVE REPRODUCIBLE CNN REFERENCE
=========================================

Dataset: CWRU 12 kHz drive-end
Window size: 256
Windows: 512
Classes: normal, inner, ball, outer

Quantization:
  input: 0.0625
  conv1_output: 0.125
  conv2_output: 0.25
  gap_output: 0.25
  logits: 0.0625

Layers:
  conv1: weight_scale=0.0078125, shift=8, weights=(8, 1, 5), bias=(8,)
  conv2: weight_scale=0.0078125, shift=8, weights=(8, 8, 3), bias=(8,)
  classifier: weight_scale=0.0078125, shift=5, weights=(4, 8), bias=(4,)

Accuracy:
  FP32: 473/512
  INT8: 462/512 (90.234375%)
  Reference errors: 50

Per-class INT8:
  normal: 128/128
  inner: 124/128
  ball: 83/128
  outer: 127/128
