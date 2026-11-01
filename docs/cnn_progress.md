# CNN Integration Progress

**Status: NOT COMPLETE — source audit only; simulation and Quartus acceptance evidence outstanding.**

## 2026-11-01 — Repository-side audit

- Working branch: `cnn-integration-audit-20261101`
- Base: `fpga-cnn-integration` at remote revision `0282c56`
- Scope: GitHub source inspection. No Icarus, Python vector rebuild, Quartus, or physical-board run was performed in this session.

### Verified findings

1. `ml/artifacts/accelerator_manifest.json` records `integer_int8_accuracy = 0.90234375` (462/512).
2. `verification/cnn_vectors/README.txt` claims INT8 accuracy 458/512 and per-class results 128/128, 128/128, 92/128, 110/128.
3. `docs/ACCEPTANCE.md` requires 458/512, but the following sentence says “If it does not reproduce 462/512”, contradicting that requirement.
4. `verification/scripts/check_cnn_reference.py` exits with failure unless there are exactly 458 correct predictions and 54 errors.
5. `verification/scripts/build_authoritative_cnn_vectors.py` uses `reference_inference()` from `generate_vectors.py` and does not assert a particular accuracy.
6. `ml/train_and_export.py` calculates its manifest INT8 metric using `integer()`: requantization rounds right shifts and GAP uses `torch.round`. In contrast, `generate_vectors.py` uses arithmetic right shift/floor behavior for MAC requantization and truncation toward zero for GAP. These are different quantization contracts and can produce different predictions.
7. `rtl/cnn_inference_top.sv` instantiates `cnn_systolic_adapter` with `start(1'b0)` and zero activation/weight inputs. The current CNN inference path therefore does not exercise the systolic adapter.
8. The current testbench source compares final logits/predictions. Source inspection does not establish the required first-32 intermediate-tensor comparisons or a passing 512-window simulation.

### Architecture decision requiring correction

The existing progress notes describe the adapter as an integration point, not as an active compute path. That is insufficient for the acceptance requirement that the CNN use the generic accelerator architecture. Conv2 must execute three K=8 systolic tiles, combine the INT32 partial sums, and only then add bias and requantize. Do not describe the adapter as integrated until the RTL and test evidence demonstrate that data actually flows through it.

### Required next work

1. Preserve the local worktree and uncommitted RTL/testbench edits.
2. Run the authoritative vector builder in the existing Python environment, without retraining. Record fresh accuracy, error indices, per-class counts, and hashes.
3. Reconcile the training/export implementation, manifest, README, acceptance criteria, and vector generator. Do not edit the checker just to force PASS.
4. Define one explicit quantization contract and make reference, checker, and RTL agree.
5. Integrate the CNN stages with the real systolic datapath, including three Conv2 K=8 partial-sum tiles combined before bias/requantization.
6. Add and verify intermediate comparisons for the first 32 windows; execute all 512 windows; verify back-to-back different-class and repeated-window cases.
7. Run the generic regression and full CNN simulation locally; preserve complete logs and exit statuses.
8. Run Quartus analysis/synthesis, fit, programming-file generation, `report_clocks`, and `check_timing` for the DE10-Standard target with a verified 20 ns clock.
9. Record only measured results here. If board execution is not performed, report physical 512-window accuracy as NOT MEASURED.

No simulation, Quartus, or physical-board result is claimed by this audit.
