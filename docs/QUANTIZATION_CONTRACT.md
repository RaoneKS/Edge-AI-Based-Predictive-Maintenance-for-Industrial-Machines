# INT8 Quantization Contract

## Authoritative deployment/reference path

For CNN systolic RTL equivalence, the canonical integer contract is the
implementation shared by:

- `verification/cnn_vectors/generate_vectors.py::reference_inference`
- `ml/hardware_reference.py::run`
- `rtl/cnn_inference_top.sv`

The canonical path performs INT8-by-INT8 products with INT32 accumulation,
adds the INT32 bias before requantization, applies optional ReLU, then uses
an arithmetic right shift and INT8 saturation. The signed GAP stage divides
the sum by 128 with truncation toward zero. The classifier uses shift 5 and
does not apply ReLU.

The full systolic-connected CNN simulation reported exact equality for all
2,048 final logit values across 512 reference windows. The first-32
intermediate-tensor checks are being added to the testbench and must be
rerun before this expanded check is claimed as passed.

## Training metric path is different

`ml/train_and_export.py::integer` is a separate training/export-time metric
path. It uses symmetric rounded requantization for positive right shifts,
`torch.round` for GAP, and clamps quantized tensors to [-127,127]. This is
not bit-identical to the deployed shift/truncation contract, which uses
arithmetic right shift (floor for negative values), truncation toward zero
for GAP, and full INT8 saturation [-128,127].

The comparison was checked against the exact saved `fp32_model.pt`, the
exported INT8 matrices, and the same 512 test windows:

| Measurement | Correct | Accuracy |
| --- | ---: | ---: |
| Training `integer()` path | 458/512 | 89.453125% |
| Deployed floor/shift + truncating-GAP reference | 462/512 | 90.234375% |

The quantized training inputs and committed 512 reference inputs were exactly
identical. The NumPy implementation in
`verification/scripts/audit_quantization_contract.py` matched the PyTorch
training function exactly: zero differing logit elements and zero differing
predictions across all 512 windows. The two arithmetic contracts produced
1,687 differing logit elements and different predicted classes on 88 windows.

The original manifest value of 0.90234375 did not match the saved checkpoint's
training `integer()` metric. Both
`ml/artifacts/accelerator_manifest.json` and
`ml/artifacts/metrics_and_quantization.json` have therefore been corrected
to 458/512 (0.89453125) for the training metric. The deployed reference remains
462/512 (0.90234375); that is the canonical source for the RTL golden vectors.

This distinction is not an RTL equivalence failure: the RTL matched the
deployed reference on all 2,048 final logits and all 512 predictions.

## Reproducible comparison

Run:

```bash
python3 verification/scripts/audit_quantization_contract.py
```

The script first verifies that the deployed floor/truncation path reproduces
the committed authoritative logits, then evaluates the rounded training
path against the same 512 INT8 inputs. It writes
`verification/results/quantization_contract_audit.json`, including accuracy,
logit-difference counts, prediction-difference indices, and whether the
rounded path reproduces the manifest's metric.

Use that measured JSON when updating the paper, manifest, README, or
performance claims. Do not substitute one path's accuracy for the other.
