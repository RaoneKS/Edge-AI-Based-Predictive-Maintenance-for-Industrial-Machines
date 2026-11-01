#!/usr/bin/env bash
# Software/RTL acceptance flow for the systolic-connected CNN.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
mkdir -p sim/acceptance_logs

echo "========== SYSTOLIC ADAPTER =========="
bash verification/scripts/run_cnn_systolic_adapter_test.sh 2>&1 | tee sim/acceptance_logs/adapter.log

echo
echo "========== FULL 512-WINDOW CNN + INTERMEDIATE CHECKS =========="
set -o pipefail
bash verification/scripts/run_cnn_e2e.sh 2>&1 | tee sim/acceptance_logs/cnn_512.log

echo
echo "========== DE10 BOARD WRAPPER NORMAL/OUTER TEST =========="
bash quartus/de10_systolic_cnn/run_wrapper_test.sh 2>&1 | tee sim/acceptance_logs/de10_wrapper.log

echo
echo "========== SOFTWARE/RTL ACCEPTANCE SUMMARY =========="
grep -E 'CNN_SYSTOLIC_ADAPTER_REGRESSION_PASS|INTERMEDIATE_TENSOR_CHECKS_PASS|SYSTOLIC_OVERFLOW_CHECK_PASS|ERROR_INDEX_COUNTS|Exact logits:|Prediction/reference:|True-label accuracy:|TOTAL_DUT_CLOCK_CYCLES=|WINDOW_LATENCY_CYCLES|CNN_E2E_TEST_PASSED' sim/acceptance_logs/cnn_512.log
grep -E 'DE10_WRAPPER_CASE_PASS|DE10_SYSTOLIC_CNN_WRAPPER_REGRESSION_PASS' sim/acceptance_logs/de10_wrapper.log
echo "SOFTWARE_RTL_ACCEPTANCE_PASS"
