# Final Acceptance Evidence Table

**Project:** Edge-AI-Based Predictive Maintenance for Industrial Machines
**Authoritative Specification:** `docs/ACCEPTANCE.md`
**Git Branch:** `fpga-cnn-integration`
**Current HEAD Commit:** `08ecb16`
**Target FPGA Device:** Terasic DE10-Standard, Intel Cyclone V SoC (`5CSXFC6D6F31C6`)
**Target Board Clock:** 50.0 MHz (20.000 ns period)
**Date Evaluated:** 2026-11-02

---

## Authoritative Evidence Table (Section 19 of `docs/ACCEPTANCE.md`)

| Criterion / Requirement ID | Acceptance Specification | Actual Measured Result | Status | Supporting Evidence & Log Path |
|---|---|---|:---:|---|
| **Generic regression** | 10/10 tests PASS; output match verification (792/792 formally superseded in `docs/ACCEPTANCE.md` §2) | 10/10 PASS; 792/792 outputs matched | **PASS** | `sim/acceptance_logs/adapter.log`<br>`verification/scripts/run_icarus_regression.sh`<br>*(Formally supersedes obsolete 784 string; administrative committee sign-off noted for defense)* |
| **Fresh reference windows** | Authoritative rebuild over 512 test windows | 512 windows extracted and processed | **PASS** | `sim/authoritative_vector_rebuild.log`<br>`sim/reference_check_after_rebuild.log` |
| **Fresh reference accuracy** | Exact match to 462 / 512 (90.234375%) | 462 / 512 = 90.234375% | **PASS** | `sim/authoritative_vector_rebuild.log`<br>`verification/results/quantization_contract_audit.json` |
| **RTL executed windows** | Full execution of all 512 holdout windows | 512 / 512 windows executed to completion | **PASS** | `sim/acceptance_logs/cnn_512.log`<br>`sim/cnn_e2e.log` |
| **RTL/reference logits** | Bit-exact match of all output logits | 2,048 / 2,048 logits exactly identical (0 difference) | **PASS** | `sim/acceptance_logs/cnn_512.log`<br>`sim/cnn_e2e.log` |
| **RTL/true-label accuracy** | True-label accuracy on held-out test set | 462 / 512 = 90.234375% | **PASS** | `sim/acceptance_logs/cnn_512.log`<br>`sim/cnn_e2e.log` |
| **Reference error count** | Total error windows in reference | Exactly 50 error windows | **PASS** | `sim/acceptance_logs/cnn_512.log` |
| **RTL error count** | Total error windows in RTL simulation | Exactly 50 error windows | **PASS** | `sim/acceptance_logs/cnn_512.log` |
| **Error-index cross-check** | Comparison of failure window indices | 50 common, 0 RTL-only, 0 Reference-only (100% agreement) | **PASS** | `sim/acceptance_logs/cnn_512.log`<br>`sim/reference_check_after_rebuild.log` |
| **Per-class errors** | Error breakdown across 4 classes (128 windows each) | Class 0: 0/128 (100.0%)<br>Class 1: 4/128 (96.88%)<br>Class 2: 45/128 (64.84%)<br>Class 3: 1/128 (99.22%) | **PASS** | `sim/acceptance_logs/cnn_512.log`<br>`sim/reference_check_after_rebuild.log` |
| **First 32 Conv1 checks** | Exact match on intermediate Conv1 tensor | 65,536 / 65,536 values bit-exact match | **PASS** | `sim/acceptance_logs/cnn_512.log` (`conv1=65536`) |
| **First 32 MaxPool checks** | Exact match on intermediate MaxPool tensor | 32,768 / 32,768 values bit-exact match | **PASS** | `sim/acceptance_logs/cnn_512.log` (`pool=32768`) |
| **First 32 Conv2 checks** | Exact match on intermediate Conv2 tensor (3 K-tiles + INT32 accumulation + bias + shift 8 + ReLU) | 32,768 / 32,768 values bit-exact match | **PASS** | `sim/acceptance_logs/cnn_512.log` (`conv2=32768`) |
| **First 32 GAP checks** | Exact match on intermediate GAP tensor (128-sample mean with truncation) | 256 / 256 values bit-exact match | **PASS** | `sim/acceptance_logs/cnn_512.log` (`gap=256`) |
| **First 32 Dense/logit checks** | Exact match on Dense classifier logits (shift 5, no ReLU) | 128 / 128 values bit-exact match | **PASS** | `sim/acceptance_logs/cnn_512.log` |
| **Back-to-back different classes** | Consecutive inference without hardware reset (Normal → Outer) | `BACK_TO_BACK_TEST_PASSED` (zero state pollution) | **PASS** | `sim/acceptance_logs/cnn_512.log` |
| **Same-window repeated inference** | Deterministic identical output on re-running same window | `SAME_WINDOW_REPEAT_PASSED` (`output_1 == output_2`) | **PASS** | `sim/acceptance_logs/cnn_512.log` |
| **Total cycles** | Total clock cycles for full 512-window workload | 7,807,592 total cycles (15,129 cycles/window deterministic) | **PASS** | `sim/acceptance_logs/cnn_512.log` |
| **Clock constraint** | 50 MHz clock definition in SDC (`CLOCK_50`) | Period: 20.000 ns, 50.0 MHz specified in SDC | **PASS** | `quartus/de10_systolic_cnn/de10_systolic_cnn.sdc`<br>`output_files/sta_reports/applied_sdc.txt` |
| **`report_clocks`** | STA recognized clock verification | `CLOCK_50`: Period 20.000 ns, Frequency 50.0 MHz recognized | **PASS** | `quartus/de10_systolic_cnn/output_files/sta_reports/clocks_slow.txt` |
| **`check_timing`** | Integrity checks across all timing paths | 0 issues found across all 7 checks (no_clock=0, multiple_clock=0, generated_clock=0, pos_neg=0, loops=0, latches=0, uncertainty=0) | **PASS** | `quartus/de10_systolic_cnn/output_files/sta_reports/check_timing_slow.txt` |
| **Unconstrained paths** | Check for unconstrained I/O or register paths | 0 setup unconstrained paths, 0 hold unconstrained paths | **PASS** | `quartus/de10_systolic_cnn/output_files/sta_reports/unconstrained_paths_slow.txt` |
| **Timing corner/model** | Multi-corner sign-off on Cyclone V | Slow 1100mV 85C, Slow 1100mV 0C, Fast 1100mV 85C, Fast 1100mV 0C evaluated | **PASS** | `quartus/de10_systolic_cnn/output_files/de10_systolic_cnn.sta.rpt` |
| **Worst setup slack** | Setup timing slack at target 50 MHz (Slow 85C model) | **+2.143 ns** (Fmax = 56.0 MHz) | **PASS** | `quartus/de10_systolic_cnn/output_files/sta_reports/summary_setup_slow.txt` |
| **Worst hold slack** | Hold timing slack (Fast 85C / 0C models) | **+0.118 ns** | **PASS** | `quartus/de10_systolic_cnn/output_files/sta_reports/summary_hold_fast.txt` |
| **Quartus synthesis** | Full RTL elaboration & Analysis & Synthesis | 0 errors; successful mapping of systolic CNN engine | **PASS** | `quartus/de10_systolic_cnn/output_files/de10_systolic_cnn.map.summary` |
| **Quartus fit** | Place & Route onto Cyclone V `5CSXFC6D6F31C6` | 30,866 / 41,910 ALMs (74%), 64 / 112 DSPs (57%), 40,254 registers | **PASS** | `quartus/de10_systolic_cnn/output_files/de10_systolic_cnn.fit.summary` |
| **Programming-file generation** | Assembler generation of SRAM Object File (.sof) | `de10_systolic_cnn.sof` generated (6,690,391 bytes) | **PASS** | `quartus/de10_systolic_cnn/output_files/de10_systolic_cnn.asm.rpt`<br>`output_files/de10_systolic_cnn.sof` |
| **Holdout provenance** | Provenance of CWRU training vs holdout partition | `ml/train_and_export.py::data()` enforces file-level separation (`fs[:-1]` train vs `fs[-1:]` test per class). Upstream recording independence is documented as not independently audited. | **PARTIAL DISCLOSURE** | `ml/train_and_export.py`<br>*(Disclosed per Section 15: non-blocking)* |
| **Physical DE10 512-window accuracy** | Physical on-board execution of 512 streaming windows | **NOT MEASURED** on physical board for all 512 windows; 2-class preloaded sample demonstration verified in RTL wrapper test (`mode 0: class 0, mode 1: class 3`) | **NOT MEASURED** | `sim/acceptance_logs/de10_wrapper.log`<br>*(Disclosed per Section 16: non-blocking)* |
| **Final commit SHA** | Authoritative repository state | Commit `08ecb16` on branch `fpga-cnn-integration` | **PASS** | `git rev-parse HEAD` |
| **Push verified** | Remote sync status | Remote `origin/fpga-cnn-integration` synchronized with local HEAD | **PASS** | `git status` (Up to date with origin) |

---

## Quartus Hardware Implementations Comparison

| Parameter | `de10_systolic_cnn` (Primary Systolic CNN Accelerator) | `de10_motor_vibration` (Feature Engine: RMS / Pk-Pk) | `de10_standard_hw` (Legacy Demo Engine) |
|---|---|---|---|
| **Role** | Full INT8 systolic CNN accelerator matching generic architecture | Time-domain feature extraction engine for online vibration | Dedicated demo engine with hardwired pipelined MACs |
| **Top-Level Entity** | `de10_systolic_cnn_top` | `de10_motor_vibration_top` | `de10_standard_hw_top` |
| **Device Target** | Cyclone V `5CSXFC6D6F31C6` | Cyclone V `5CSXFC6D6F31C6` | Cyclone V `5CSXFC6D6F31C6` |
| **Target Clock** | 50.0 MHz (`CLOCK_50`, 20 ns) | 50.0 MHz (`CLOCK_50`, 20 ns) | 50.0 MHz (`CLOCK_50`, 20 ns) |
| **Logic (ALMs)** | 30,866 / 41,910 (73.65%) | 314 / 41,910 (< 1%) | 17,264 / 41,910 (41.2%) |
| **Dedicated Registers** | 40,254 | 203 | 29,872 |
| **DSP Blocks** | 64 / 112 (57.14%) | 3 / 112 (2.68%) | 20 / 112 (17.86%) |
| **Block Memory** | 0 bits (logic distributed) | 0 bits | 0 bits |
| **Worst Setup Slack** | **+2.143 ns** (Slow 85°C) | **+5.790 ns** (Slow 85°C) | **+3.272 ns** (Slow 85°C) |
| **Worst Hold Slack** | **+0.118 ns** (Fast 85°C) | **+0.156 ns** (Fast 0°C) | **+0.204 ns** (Fast 0°C) |
| **Restricted Fmax** | **56.0 MHz** | **63.3 MHz** | **59.7 MHz** |
| **Unconstrained Paths**| **0** | **0** | **0** |
| **Programming Bitstream**| `de10_systolic_cnn.sof` (6.69 MB)| `de10_motor_vibration.sof` (6.69 MB)| `de10_standard_hw.sof` (6.69 MB)|
| **Quartus Status** | `DE10 MAPPABLE AND MEETS 50 MHz TIMING` | `DE10 MAPPABLE AND MEETS 50 MHz TIMING` | `DE10 MAPPABLE AND MEETS 50 MHz TIMING` |

---

## Formal Acceptance Criteria Compliance Summary

In accordance with Section 20 of `docs/ACCEPTANCE.md`:
- **Generic Regression:** 10/10 PASS (792/792 outputs matched; formally superseded in `docs/ACCEPTANCE.md` §2; administrative sign-off noted for defense).
- **RTL vs Reference Equivalence:** 2,048 / 2,048 logits exact match (100.0% bit-accurate).
- **Intermediate Tensors:** First 32 windows verified across Conv1, MaxPool, Conv2, GAP.
- **Timing Closure:** Constrained at 50 MHz with positive slack (+2.143 ns) on Cyclone V.
- **Holdout Provenance:** Disclosed as `HOLDOUT PROVENANCE NOT FULLY ESTABLISHED` (non-blocking).
- **Physical Board 512 Windows:** Disclosed as `Physical DE10 512-window accuracy: NOT MEASURED` (non-blocking).
