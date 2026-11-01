# CNN Integration Progress

**Status: NOT COMPLETE — adapter unit regression and fresh Python reference rebuild passed; CNN RTL equivalence and Quartus acceptance evidence outstanding.**

## 2026-11-01 — Repository-side audit

- Working branch: `cnn-integration-audit-20261101`
- Base: `fpga-cnn-integration` at remote revision `0282c56`
- Scope: repository audit plus user-executed local Icarus adapter regression and Python vector rebuild. No full CNN RTL simulation, Quartus run, or physical-board run has been established.

### Verified findings

1. `ml/artifacts/accelerator_manifest.json` records `integer_int8_accuracy = 0.90234375` (462/512).
2. The README previously claimed 458/512 and per-class counts that did not match a fresh rebuild; it has now been corrected to the measured 462/512 counts.
3. `docs/ACCEPTANCE.md` previously contradicted itself (458/512 target versus a 462/512 stop condition); the canonical reference requirement is now 462/512, consistent with the manifest and fresh vector rebuild.
4. The checker previously hard-coded 458 correct predictions and 54 errors; it has now been corrected to 462 correct predictions and 50 errors.
5. `verification/scripts/build_authoritative_cnn_vectors.py` uses `reference_inference()` from `generate_vectors.py` and does not assert a particular accuracy.
6. `ml/train_and_export.py` calculates its manifest INT8 metric using `integer()`: requantization rounds right shifts and GAP uses `torch.round`. In contrast, `generate_vectors.py` uses arithmetic right shift/floor behavior for MAC requantization and truncation toward zero for GAP. These are different quantization contracts and can produce different predictions.
7. `rtl/cnn_inference_top.sv` instantiates `cnn_systolic_adapter` with `start(1'b0)` and zero activation/weight inputs. The current CNN inference path therefore does not exercise the systolic adapter.
8. The current testbench source compares final logits/predictions. Source inspection does not establish the required first-32 intermediate-tensor comparisons or a passing 512-window simulation.

### Local verification evidence (2026-11-01)

- User ran `bash verification/scripts/run_cnn_systolic_adapter_test.sh` on the audit branch.
- Result: five deterministic 8x8 adapter matrix trials passed; each completed in 20 cycles; no overflow; terminal marker `CNN_SYSTOLIC_ADAPTER_REGRESSION_PASS`.
- User backed up existing `.npy` vectors to `/home/raone/cnn_vectors_backup_20261101_165120` before rebuilding.
- User reran `verification/scripts/build_authoritative_cnn_vectors.py` without retraining. It reported `AUTHORITATIVE_REFERENCE_ACCURACY=462/512`.
- Fresh reference checker output: 462/512 (90.234375%), 50 errors. Per-class correct counts: class 0 128/128, class 1 124/128, class 2 83/128, class 3 127/128.
- The prior checker failed only because its expected 458/512 and 54-error constants were stale. It is updated to the freshly reproduced 462/512 baseline; this does not establish RTL/reference equivalence.
- User ran `bash verification/scripts/run_cnn_e2e.sh` at local HEAD `dfe2b5564306ac29959ef8bd5e107e64fd928a55`. The script's reference checker passed; Icarus compilation succeeded; simulation executed all 512 windows; result `Exact logits: 2048/2048`, `Prediction/reference: 512/512`, `True-label accuracy: 462/512`; both back-to-back and same-window-repeat tests passed; terminal marker `CNN_E2E_TEST_PASSED`.
- The simulation was run with the user's locally modified, uncommitted RTL/testbench files (`rtl/cnn_inference_top.sv` and `tb/tb_cnn_inference_top.sv` were shown modified before the run). Preserve those edits and record their diff before committing them.
- One non-fatal testbench warning remains: Conv1 `$readmemh` reads 64 padded weights into `c1w_mem[0:39]`. The RTL currently consumes the first 40 logical K=5 weights. Expand only the testbench read buffer to 64 entries (keep the flat module port at 40 weights) to remove the warning, then rerun the test.
- The E2E testbench still prints the stale banner `Reference expected accuracy: 458/512 = 89.453125%`; update it to 462/512 = 90.234375%.
- The standalone command `python3 verification/scripts/check_cnn_reference.py` failed because the system Python lacks NumPy; the E2E script subsequently completed the checker successfully using its selected Python interpreter. Use `.venv/bin/python3` for standalone checks if available.
- Fresh vector SHA-256 values (as printed by the user): `input_int8.npy` `591aeba785cc0d6f1db92e2e4bcfb3ef292ea80761c2d2850e7d282b81d9913b`; `reference_logits_int8.npy` `e9715d4244dab05a974afd41e8af118c72a9768a61e635772c1909d4326aa231`; `reference_predictions.npy` `a308ee3c108e5a06dc2eed0137b9d17786a3d7d4c5cf43e8026793674c6af097`.

### Architecture decision requiring correction

The existing progress notes describe the adapter as an integration point, not as an active compute path. That is insufficient for the acceptance requirement that the CNN use the generic accelerator architecture. Conv2 must execute three K=8 systolic tiles, combine the INT32 partial sums, and only then add bias and requantize. Do not describe the adapter as integrated until the RTL and test evidence demonstrate that data actually flows through it.

### Required next work

1. Preserve the local worktree and uncommitted RTL/testbench edits.
2. Fresh authoritative vector regeneration is complete: 462/512, 50 errors, per-class counts and key hashes are recorded above. Keep the generated artifacts reproducible.
3. The README, acceptance criteria, and checker now use the measured 462/512 reference baseline. Still reconcile the distinct rounding rules in `train_and_export.py` (rounded right shifts/GAP) versus `generate_vectors.py` (arithmetic shift/truncation toward zero); equal classification accuracy does not prove identical intermediate tensors or logits.
4. Define one explicit quantization contract and make reference, checker, and RTL agree.
5. Integrate the CNN stages with the real systolic datapath, including three Conv2 K=8 partial-sum tiles combined before bias/requantization.
6. Add and verify intermediate comparisons for the first 32 windows; execute all 512 windows; verify back-to-back different-class and repeated-window cases.
7. Run the generic regression and full CNN simulation locally; preserve complete logs and exit statuses.
8. Run Quartus analysis/synthesis, fit, programming-file generation, `report_clocks`, and `check_timing` for the DE10-Standard target with a verified 20 ns clock.
9. Record only measured results here. If board execution is not performed, report physical 512-window accuracy as NOT MEASURED.

Full CNN E2E simulation is now claimed as passed for the user's local scalar CNN RTL path, based on the reported logs above. No claim is made that the CNN path exercises the systolic adapter: the inspected CNN top ties adapter start and data inputs to zero. No Quartus or physical-board result is claimed.
