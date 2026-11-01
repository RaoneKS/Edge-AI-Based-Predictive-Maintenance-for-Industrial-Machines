# CNN Integration Progress

**Status: Full 512-window systolic CNN simulation PASS. Quartus timing/fit, intermediate-tensor audit, and physical-board validation remain outstanding.**

## Branch and scope

- Working branch: `cnn-integration-audit-20261101`
- Base: `fpga-cnn-integration` at `0282c56`
- This is an isolated audit/work branch. No changes were made directly to `main`.
- The branch contains the CNN-to-systolic integration in `rtl/cnn_inference_top.sv`, its adapter, testbenches, scripts, and evidence documentation.

## Verified on 2026-11-01

### Systolic adapter unit regression

User ran `bash verification/scripts/run_cnn_systolic_adapter_test.sh`.

- Five deterministic 8x8 matrix trials passed.
- Each trial completed in 20 cycles.
- Terminal markers: `CNN_SYSTOLIC_ADAPTER_TEST_PASS trials=5` and `CNN_SYSTOLIC_ADAPTER_REGRESSION_PASS`.

### Full CNN systolic end-to-end simulation

User ran `bash verification/scripts/run_cnn_e2e.sh` using Icarus at commit:

`5b54b175e98e5d4213c1c1f6010c7bde2718e9e3`

The command completed with `CNN_SYSTOLIC_E2E_EXIT_STATUS=0` and `CNN_E2E_TEST_PASSED`.

| Measurement | Result |
| --- | ---: |
| Input windows executed | 512/512 |
| Exact final logits vs Python reference | 2048/2048 |
| Predictions vs Python reference | 512/512 |
| Correct predictions against labels | 462/512 (90.234375%) |
| Class 0 (normal) | 128/128 |
| Class 1 (inner) | 124/128 |
| Class 2 (ball) | 83/128 |
| Class 3 (outer) | 127/128 |
| Different-window back-to-back test | PASS |
| Same-window repeat without reset | PASS |

Interpretation:
- 512/512 and 2048/2048 establish final-output equivalence to the committed Python reference for the tested holdout.
- 462/512 is the reference/RTL classification accuracy against the dataset labels; it is not a physical-board accuracy measurement.
- The successful full run was performed at the integration commit above. Follow-up commits added bounded smoke-run support, corrected a display denominator, and added handoff/package documentation; they did not change the CNN datapath RTL.

### Fresh Python reference

The authoritative vector checker reproduced:
- 512 windows.
- 462 correct predictions (90.234375%).
- 50 reference error windows.
- Per-class correct counts: 128/128, 124/128, 83/128, and 127/128.

The vector builder uses `reference_inference()` from `verification/cnn_vectors/generate_vectors.py` and committed model/data artifacts. It does not retrain the model.

## RTL implementation summary

The current CNN top routes Conv1, Conv2, and classifier matrix operations through `cnn_systolic_adapter`.

- Conv1: one K=8 transaction per spatial position; five logical features plus three zero lanes; bias/requantization/ReLU applied after tile completion.
- Conv2: three K=8 transactions per spatial position; INT32 partial sums are combined before bias/requantization/ReLU/saturation.
- Classifier: one K=8 transaction, with four logical output columns used.
- GAP remains a direct reduction stage.

The standalone adapter regression validates five deterministic matrix cases. The full CNN run validates final outputs for all 512 holdout windows.

## Remaining work and caveats

1. **Intermediate-tensor coverage:** The current full testbench checks final logits and predictions. It does not yet provide the required exact intermediate checks for Conv1, MaxPool, Conv2, and GAP on the first 32 windows.
2. **Error-index comparison:** The reference has 50 known error indices. A separate report comparing RTL error indices, reference error indices, common errors, RTL-only errors, and reference-only errors is still needed.
3. **Overflow handling:** Review the adapter overflow signal and confirm that the CNN top reports or safely handles it for every transaction.
4. **Quantization contract:** `ml/train_and_export.py` computes its manifest INT8 metric using rounded right shifts and `torch.round` for GAP. `verification/cnn_vectors/generate_vectors.py` uses arithmetic-shift/floor semantics and truncation toward zero for GAP. These are different quantization contracts; reconcile and document which exported model contract is authoritative.
5. **Generic regression output-count discrepancy:** The ten generic Icarus cases all reported PASS, but the per-case counts shown in the run sum to 792 outputs, while `docs/ACCEPTANCE.md` still specifies 784/784. The discrepancy is unresolved; do not report 784/784 as the current run result.
6. **Quartus:** No current-source Quartus compile/fit and STA result has been established for the systolic-connected CNN top. Clock recognition, 20 ns period, unconstrained paths, worst setup slack, worst hold slack, and resource use remain unverified for this integration.
7. **Physical board:** No programming or on-board execution result has been established. Report physical DE10 accuracy as NOT MEASURED until tested.

## Reproduction

From the repository root:

```bash
bash verification/scripts/run_cnn_systolic_adapter_test.sh
bash verification/scripts/run_cnn_e2e.sh
```

The E2E script prepares the Icarus hex files in `sim/cnn_vectors/`, compiles the RTL/testbench, and runs all 512 windows. Use the exact commit SHA and retain the resulting log with any shared result.

## Teammate bundle

See `docs/TEAMMATE_QUICKSTART.md`. Run `bash scripts/package_teammate_bundle.sh` to export the committed source tree, a file manifest, checksums, and the validated full-run log when available.
