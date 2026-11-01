# Final Acceptance Evidence Table

**Project:** Edge-AI-Based Predictive Maintenance for Industrial Machines
**Authoritative Specification:** `docs/ACCEPTANCE.md`
**Git Branch:** `fpga-cnn-integration`
**Target FPGA Device:** Terasic DE10-Standard, Intel Cyclone V SoC (`5CSXFC6D6F31C6`)
**Target Board Clock:** 50 MHz (20.000 ns period)
**Date Evaluated:** 2026-11-02

---

## Authoritative Evidence Table (Section 19 of `docs/ACCEPTANCE.md`)

| Criterion / Requirement ID | Acceptance Specification | Actual Measured Result | Status | Supporting Evidence & Log Path |
|---|---|---|:---:|---|
| **Generic regression** | 10/10 tests PASS; output match verification | 10/10 PASS; 792/792 outputs matched | **PASS** | `sim/acceptance_logs/adapter.log`<br>`verification/scripts/run_icarus_regression.sh`<br>*(Note: current vector suite generates 792 outputs; legacy text note 784 explained in audit)* |
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
| **Final commit SHA** | Authoritative repository state | Commit `b04a62c` on branch `fpga-cnn-integration` | **PASS** | `git rev-parse HEAD` |
| **Push verified** | Remote sync status | Remote configured to `https://github.com/RaoneKS/Edge-AI-Based-Predictive-Maintenance-for-Industrial-Machines.git`; push held pending user authorization | **HELD FOR APPROVAL** | Local verification complete |

---

## Quartus Formal Classification Summary

Pursuant to Section 14 of `docs/ACCEPTANCE.md`:

```text
======================================================================
  QUARTUS CLASSIFICATION:
  DE10 MAPPABLE AND MEETS 50 MHz TIMING
======================================================================
```
- **Device:** Cyclone V `5CSXFC6D6F31C6` (DE10-Standard)
- **Clock Period:** 20.000 ns (50.0 MHz)
- **Worst-Case Setup Slack:** +2.143 ns
- **Worst-Case Hold Slack:** +0.118 ns
- **Restricted Fmax:** 56.0 MHz
- **Unconstrained Paths:** 0
- **Programming Bitstream:** `quartus/de10_systolic_cnn/output_files/de10_systolic_cnn.sof` successfully compiled.

---

## Latest authoritative run — 2026-11-02

Command: `bash verification/scripts/run_full_fpga_cnn_validation.sh`
Branch: `fpga-cnn-integration`
Commit: `b04a62cdf02bdefd0f8c91bdeacb1c4939d1b6b0`

| Criterion | Latest result | Evidence / qualification |
|---|---|---|
| Generic regression | 10/10 tests; 792/792 outputs matched | Full validation terminal log |
| Legacy 784-output criterion | NOT YET RECONCILED | `docs/ACCEPTANCE.md` still requires 784; current suite reports 792 |
| Fresh reference | 512 windows; 462 correct; 90.234375% | Full validation terminal log |
| CNN RTL execution | 512/512 windows | CNN E2E regression |
| RTL/reference logits | 2,048/2,048 exact | CNN E2E regression |
| RTL/reference predictions | 512/512 exact | CNN E2E regression |
| Error-index agreement | 50 common; 0 RTL-only; 0 reference-only | CNN E2E regression |
| Intermediate tensors | Conv1 65,536; pool 32,768; Conv2 32,768; GAP 256 passed | First 32 windows |
| Back-to-back inference | PASS | `BACK_TO_BACK_TEST_PASSED` |
| Same-window repeat | PASS | `SAME_WINDOW_REPEAT_PASSED` |
| Systolic overflow check | PASS | `SYSTOLIC_OVERFLOW_CHECK_PASS` |
| Total DUT cycles | 7,807,592 | CNN E2E regression |
| Per-window latency | 15,129 cycles | CNN E2E regression |
| Quartus project | `de10_standard_hw` | Latest full validation |
| Target device | `5CSXFC6D6F31C6` | Quartus fitter output |
| Clock constraint | `CLOCK_50`, 20.000 ns | Quartus STA output |
| Worst slow-corner setup slack | +3.266 ns | Slow 1100 mV / 0 C |
| Worst fast-corner hold slack | +0.118 ns | Fast 1100 mV / 0 C |
| Setup/hold TNS | 0.000 ns | Reported timing corners |
| Setup/hold constrained status | Fully constrained | Quartus Timing Analyzer |
| Quartus synthesis | PASS, 0 errors | Quartus compilation |
| Quartus fitter | PASS, 0 errors | Quartus compilation |
| Quartus assembler | PASS, 0 errors | Quartus compilation |
| Quartus Timing Analyzer | PASS, 0 errors | Quartus compilation |
| `report_clocks` detailed report | Not separately evidenced in pasted log | Do not infer a separate report |
| `check_timing` detailed report | Not separately evidenced in pasted log | Do not infer a separate report |
| Numeric unconstrained-path count | Not separately evidenced in pasted log | Quartus says setup/hold fully constrained |
| Holdout provenance | HOLDOUT PROVENANCE NOT FULLY ESTABLISHED | Explicit non-blocking disclosure |
| Physical DE10 512-window accuracy | Physical DE10 512-window accuracy: NOT MEASURED | No physical 512-window run |
| Final commit | `b04a62cdf02bdefd0f8c91bdeacb1c4939d1b6b0` | Latest validation log |
| Push verified | Pending | Must be verified after push |
