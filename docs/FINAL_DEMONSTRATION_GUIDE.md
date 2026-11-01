# Final Demonstration and Reproduction Guide
## Edge-AI Predictive Maintenance on Intel Cyclone V FPGA

This document provides exact, reproducible instructions for evaluating the FPGA-based Edge-AI predictive maintenance system.

---

## 1. System Requirements & Environment

- **Host OS:** Ubuntu Linux (tested on 22.04 / 24.04 / 26)
- **Simulators:** Icarus Verilog (`iverilog` version 12+), `vvp`
- **Python Environment:** Python 3.8+ with virtualenv at `~/fpga-ai-accelerator/.venv`
- **FPGA Toolchain:** Intel Quartus Prime Lite Edition (tested on version 25.1std.0 Build 1129)
- **Target Hardware:** Terasic DE10-Standard (Cyclone V SoC `5CSXFC6D6F31C6`)

---

## 2. Fast Smoke Test (Generic Accelerator Baseline)

Verify that the generic $8\times 8$ systolic array accelerator regression suite passes:

```bash
cd ~/fpga-ai-accelerator
source .venv/bin/activate
bash verification/scripts/run_icarus_regression.sh
```

**Expected Console Output:**
```text
Generating: test_identity_8x8
Generating: test_random_small
...
  RESULT: PASS (240/240 outputs matched)
...
  RESULT: PASS (16/16 outputs matched)
TEST PASSED
```
*Total verification: 10/10 tests PASS, 792/792 outputs matched with zero mismatches.*

---

## 3. Fresh Authoritative Reference Generation

Rebuild the authoritative test vectors and golden classification predictions from the saved model artifacts:

```bash
cd ~/fpga-ai-accelerator
source .venv/bin/activate
python3 verification/scripts/build_authoritative_cnn_vectors.py
python3 verification/scripts/check_cnn_reference.py
```

**Expected Console Output:**
```text
windows: 512
correct: 462
accuracy: 90.234375%
errors: 50
class_0: 128/128 = 100.000000%
class_1: 124/128 = 96.875000%
class_2: 83/128 = 64.843750%
class_3: 127/128 = 99.218750%
CNN_REFERENCE_CHECK_PASSED
```

---

## 4. End-to-End CNN RTL Simulation (Full 512 Windows)

Run the full hardware simulation of the 1D-CNN pipeline across all 512 holdout windows:

```bash
cd ~/fpga-ai-accelerator
source .venv/bin/activate
bash verification/scripts/run_cnn_e2e.sh
```

**Key Execution Stages:**
1. Loads 512 windows into testbench memory.
2. Evaluates intermediate tensors for the first 32 windows (Conv1, MaxPool, Conv2, GAP).
3. Executes all 512 windows through systolic tiling FSM and requantization unit.
4. Performs sequential back-to-back tests (Normal $\to$ Outer) and repeated same-window tests.
5. Verifies error indices against software golden model.

**Expected Final Console Summary:**
```text
Progress: 512/512 windows
BACK_TO_BACK_TEST_PASSED
SAME_WINDOW_REPEAT_PASSED
ERROR_INDEX_COUNTS reference=50 rtl=50 common=50 rtl_only=0 reference_only=0
INTERMEDIATE_TENSOR_CHECKS_PASS windows=32 conv1=65536 pool=32768 conv2=32768 gap=256
SYSTOLIC_OVERFLOW_CHECK_PASS

=== CNN E2E RESULT ===
Windows: 512
Exact logits: 2048/2048
Prediction/reference: 512/512
True-label accuracy: 462/512
Reference expected accuracy: 462/512 = 90.234375%
TOTAL_DUT_CLOCK_CYCLES=7807592
WINDOW_LATENCY_CYCLES min=15129 max=15129 avg=15129
CNN_E2E_TEST_PASSED
```

---

## 5. Consolidated Software Acceptance Suite

To execute all software, adapter, and wrapper tests in a single command:

```bash
cd ~/fpga-ai-accelerator
source .venv/bin/activate
bash verification/scripts/run_cnn_software_acceptance.sh
```

Logs are preserved in `sim/acceptance_logs/`:
- `adapter.log`: 5/5 trials passed for systolic adapter.
- `cnn_512.log`: Full 512-window E2E simulation.
- `de10_wrapper.log`: Preloaded Normal (class 0) and Outer (class 3) wrapper test.
- `quantization_contract.log`: Contract validation audit.

---

## 6. Quartus Synthesis and Static Timing Sign-Off

To compile the DE10-Standard systolic CNN hardware project:

```bash
cd ~/fpga-ai-accelerator/quartus/de10_systolic_cnn
bash run_quartus.sh
```

**Key Verification Outputs:**
- Compilation Status: `output_files/de10_systolic_cnn.flow.rpt`
- Resource Utilization: `output_files/de10_systolic_cnn.fit.summary`
- Static Timing Analysis: `output_files/sta_reports/`
  - Clocks: `cat output_files/sta_reports/clocks_slow.txt`
  - Setup Slack: `cat output_files/sta_reports/summary_setup_slow.txt` ($\ge 0$ ns required)
  - Hold Slack: `cat output_files/sta_reports/summary_hold_fast.txt` ($\ge 0$ ns required)
  - Unconstrained Paths: `cat output_files/sta_reports/unconstrained_paths_slow.txt` (must be 0)
- Programming Bitstream: `output_files/de10_systolic_cnn.sof`

---

## 7. Board Demonstration Mode (Preloaded Sample Verification)

The DE10-Standard top-level design (`quartus/de10_systolic_cnn/de10_systolic_cnn_top.sv`) includes hardware sample ROMs for two diagnostic test cases:
- `SW[0] = 0`: Normal vibration window $\to$ Expected classification: **Class 0 (Normal)**.
  - Logits: `[39, 2, -36, -51]`.
  - LEDs: `LEDR[3:0] = 4'b0001`, `LEDR[9] = 1` (Done), `LEDR[8] = 0` (No overflow).
- `SW[0] = 1`: Outer-race fault window $\to$ Expected classification: **Class 3 (Outer Race Fault)**.
  - Logits: `[-33, 3, 9, 15]`.
  - LEDs: `LEDR[3:0] = 4'b1000`, `LEDR[9] = 1` (Done), `LEDR[8] = 0` (No overflow).

Simulation of this exact top-level wrapper is verified via:
```bash
cd ~/fpga-ai-accelerator/quartus/de10_systolic_cnn
bash run_wrapper_test.sh
```
**Output:**
```text
DE10_WRAPPER_CASE_PASS mode=0 class=0 cycles=15134
DE10_WRAPPER_CASE_PASS mode=1 class=3 cycles=15131
DE10_SYSTOLIC_CNN_WRAPPER_TEST_PASS
```
