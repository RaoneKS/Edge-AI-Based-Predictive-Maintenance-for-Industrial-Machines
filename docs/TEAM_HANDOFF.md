# Team Handoff — FPGA AI Inference Accelerator

## Package identity

- Repository: `RaoneKS/predictive-churn-aware-cfisac`
- Working branch: `cnn-integration-audit-20261101`
- Purpose: teammate handoff of the complete tracked source tree for the INT8 systolic accelerator and CWRU bearing-CNN application.
- This handoff branch is intentionally separate from `main` and `fpga-cnn-integration`. Do not merge it into another branch without reviewing the outstanding acceptance items below.

## What is included

The branch contains the tracked project source and data, including:

- `rtl/`: SystemVerilog accelerator, systolic array, CNN adapter and CNN inference implementation.
- `tb/`: RTL testbenches, including generic accelerator, CNN adapter and CNN end-to-end benches.
- `verification/`: Python reference/vector-generation scripts, tracked reference arrays, regression vectors and test scripts.
- `ml/`: model training/export/reference code, model artifacts and the CWRU data subset checked into the repository.
- `quartus/`: DE10-Standard project files, constraints, board-level support and model data.
- `third_party/reference/`: reference projects and their source files as stored in this repository.
- `docs/` and root documentation: design notes, acceptance criteria, progress records and project description.

A Git branch ZIP or `git archive` contains every file tracked at the selected commit. It does not contain Git history, ignored files, untracked local simulation output, local virtual environments, or local backup files. Use `git clone` instead of ZIP when teammates need full Git history and the ability to push branches.

## Environment

The CNN Icarus flow requires:

- Linux (commands below assume Ubuntu/Debian).
- Python 3.
- NumPy available to the Python interpreter used by the scripts.
- Icarus Verilog tools: `iverilog` and `vvp`.

Install the OS simulator package and Python dependency:

```bash
sudo apt update
sudo apt install -y git zip unzip iverilog
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip numpy
```

If the authoritative vectors must be regenerated from the checked-in MAT dataset, install SciPy as well:

```bash
python -m pip install scipy
```

No FPGA board is required for the Icarus simulation tests. Quartus is needed for the separate FPGA implementation/STA flow.

## Reproduce the verified CNN tests

From the repository root:

```bash
source .venv/bin/activate
bash verification/scripts/run_cnn_systolic_adapter_test.sh
bash verification/scripts/run_cnn_e2e.sh
```

The E2E script uses tracked authoritative `.npy` reference vectors when present. If they are absent, it attempts to rebuild them from committed model/data artifacts. It emits generated simulator files under `sim/` and `work/`; those are local build products, not source files.

For a quick smoke test, use:

```bash
CNN_E2E_ARGS="+num_windows=1" bash verification/scripts/run_cnn_e2e.sh
```

The smoke mode is for quick debugging only. The full acceptance run is the 512-window command above.

## Verification evidence recorded on this branch

The project owner reported the following local Icarus results on 2026-11-01:

1. Systolic adapter unit regression:
   - Five deterministic 8x8 matrix trials passed.
   - Each trial completed in 20 cycles.
   - Terminal marker: `CNN_SYSTOLIC_ADAPTER_REGRESSION_PASS`.

2. Systolic-connected CNN end-to-end run:
   - All 512 input windows executed.
   - Exact RTL/reference logits: 2048/2048.
   - RTL/reference predictions: 512/512.
   - Back-to-back inference passed.
   - Same-window repeat without reset passed.
   - Terminal marker: `CNN_E2E_TEST_PASSED`.
   - Reference and RTL simulation true-label accuracy: 462/512 (90.234375%). This is a simulation result, not a physical FPGA-board measurement.

The full 512-window result was produced on the same systolic-connected RTL before later testbench-only updates for bounded smoke mode, output flushing and the displayed logits denominator. Re-run the two commands above on the exact commit used by your team and retain the new logs as your own reproducibility evidence.

## Important open items — do not overstate completion

- The acceptance document still asks for exact comparisons of intermediate Conv1, MaxPool, Conv2, GAP and Dense tensors for the first 32 windows. The currently reported E2E evidence establishes final logits/predictions, not those intermediate tensor checks.
- The generic accelerator regression has ten passing cases, but its per-case matched-output counts sum to 792 while `docs/ACCEPTANCE.md` specifies 784/784 and explicitly rejects substituting 792/792. Resolve this provenance/count discrepancy before declaring the generic baseline accepted.
- Quartus synthesis/fit/programming-file generation and timing evidence using `report_clocks` and `check_timing` have not been established by the Icarus results above.
- Physical DE10 512-window accuracy is not measured by a simulator run. Report it as NOT MEASURED unless the board is actually programmed and the experiment is recorded.
- The source-level model/reference quantization contract differences documented in `docs/cnn_progress.md` should remain visible in any paper or presentation until reconciled.

Read these files first:
1. `README.md`
2. `docs/ACCEPTANCE.md`
3. `docs/cnn_progress.md`
4. `APPLICATION_ACCELERATOR.md` (if present at the repository root)

## Suggested team workflow

1. One teammate reviews the CNN RTL and its systolic adapter.
2. One teammate independently reruns the adapter and 512-window CNN simulations.
3. One teammate audits the Python quantization/reference path and acceptance discrepancies.
4. Keep changes on feature branches; record simulator versions, commit SHA, commands, complete logs and exit status with every reported result.

Do not edit or delete local backups or stash entries from the original developer's workstation as part of this handoff; they are not part of the committed project package.
