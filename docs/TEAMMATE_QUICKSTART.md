# Teammate Handoff — FPGA AI Inference Accelerator

## Source snapshot

Use the branch **`cnn-integration-audit-20261101`** for this handoff. It contains the CNN-to-systolic integration work and verification updates. It is an audit/work branch; it has not been merged into `main`.

Repository: https://github.com/RaoneKS/predictive-churn-aware-cfisac

Download the branch as a ZIP:
https://github.com/RaoneKS/predictive-churn-aware-cfisac/archive/refs/heads/cnn-integration-audit-20261101.zip

For ongoing collaboration with Git history:

```bash
git clone --single-branch --branch cnn-integration-audit-20261101 \
  https://github.com/RaoneKS/predictive-churn-aware-cfisac.git
cd predictive-churn-aware-cfisac
```

## What is included

The Git-tracked source snapshot includes the SystemVerilog RTL, testbenches, Python model/reference and vector-generation code, model artifacts, committed CWRU dataset subset, verification scripts and vectors, Quartus/DE10 project files, documentation, and tracked third-party reference material.

The ZIP packager also includes the raw successful CNN E2E console log when it finds the completed local file `sim/cnn_systolic_integration_run.log`. It deliberately does not include `.git` history, untracked local files, personal backup copies, or simulator scratch outputs. Use `git clone` rather than the ZIP when history is required.

## Environment

For the Icarus-based verification on Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y git zip unzip python3 python3-venv python3-pip iverilog
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install numpy scipy
```

The scripts automatically prefer `.venv/bin/python3` when it exists. Quartus is not required for the simulation tests. Model retraining/export may need additional ML packages; the verification flow uses the committed model artifacts and CWRU subset and does not retrain the network.

## Run the tests

From the repository root:

```bash
bash verification/scripts/run_cnn_systolic_adapter_test.sh
bash verification/scripts/run_cnn_e2e.sh
```

The CNN E2E script creates simulator outputs under `sim/`. Those files are generated locally and are not needed in the source ZIP because the script recreates them from committed vectors and artifacts.

Optional generic accelerator regression:

```bash
bash verification/scripts/run_icarus_regression.sh
```

## Verification status recorded on 2026-11-01

### CNN systolic adapter

The five deterministic adapter trials passed. Each trial reported 20 cycles, and the script ended with:

```text
CNN_SYSTOLIC_ADAPTER_TEST_PASS trials=5
CNN_SYSTOLIC_ADAPTER_REGRESSION_PASS
```

### Full systolic CNN E2E

The user-run full 512-window Icarus simulation completed with exit status 0. Reported results:

| Check | Result |
| --- | ---: |
| Windows simulated | 512/512 |
| Exact RTL/reference logits | 2048/2048 |
| RTL/reference predictions | 512/512 |
| Reference/RTL true-label correct | 462/512 (90.234375%) |
| Normal | 128/128 |
| Inner | 124/128 |
| Ball | 83/128 |
| Outer | 127/128 |
| Different-window back-to-back check | PASS |
| Same-window repeat without reset | PASS |

The 462/512 figure is classification accuracy against labels for the exported INT8 model on this 512-window holdout. The 512/512 figure is RTL-to-Python prediction equivalence. They are different metrics. This is simulation evidence, not physical FPGA accuracy.

The complete run output should be retained as `verification/evidence/cnn_systolic_512_window_pass.log` in a teammate bundle, if the local validated log is available when the packager runs.

### Remaining validation items / known caveats

- A Quartus compile/fit and timing analysis of the current systolic-connected CNN top has not been established by the evidence above. Do not claim current DE10 timing closure or resource use from this simulation.
- Physical programming/execution on a DE10-Standard board has not been established.
- The generic accelerator regression script runs ten cases. Current reported per-case matched outputs sum to 792, while `docs/ACCEPTANCE.md` still specifies 784/784. All ten cases passed, but that aggregate acceptance discrepancy remains unresolved; do not relabel it as 784/784.
- The repository README contains historical/general accelerator claims. Use the test logs and the status above for the specific CNN systolic integration status.

## Create a shareable ZIP from a local clone

After cloning or pulling the branch, run:

```bash
bash scripts/package_teammate_bundle.sh
```

By default, the ZIP is written into a sibling directory named `teammate_bundles`. A custom destination can be supplied:

```bash
bash scripts/package_teammate_bundle.sh /path/to/output
```

The script exports every file tracked by the checked-out Git commit, adds a commit/file manifest and SHA-256 checksums, checks the ZIP, and includes the validated CNN E2E log if present. It does not package untracked local backups or the contents of `.git`.

## Team workflow

- Keep work on `cnn-integration-audit-20261101` or a feature branch based on it until review is complete.
- Do not force-push or reset shared branches.
- Before editing, run `git status --short`; preserve local changes and stashes.
- Share test logs together with the exact commit SHA used for the run.
