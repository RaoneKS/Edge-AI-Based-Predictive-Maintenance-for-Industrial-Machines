#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${ROOT}/sim/cnn_systolic_adapter"
mkdir -p "${OUT}"
command -v iverilog >/dev/null || { echo "ERROR: iverilog is required" >&2; exit 127; }
command -v vvp >/dev/null || { echo "ERROR: vvp is required" >&2; exit 127; }
iverilog -g2012 -I"${ROOT}/rtl" \
  "${ROOT}/rtl/pkg_accelerator.sv" \
  "${ROOT}/rtl/mac_unit.sv" \
  "${ROOT}/rtl/systolic_array.sv" \
  "${ROOT}/rtl/cnn_systolic_adapter.sv" \
  "${ROOT}/tb/tb_cnn_systolic_adapter.sv" \
  -o "${OUT}/adapter.vvp" 2>&1 | tee "${OUT}/compile.log"
vvp "${OUT}/adapter.vvp" 2>&1 | tee "${OUT}/run.log"
grep -q "CNN_SYSTOLIC_ADAPTER_TEST_PASS trials=5" "${OUT}/run.log"
echo "CNN_SYSTOLIC_ADAPTER_REGRESSION_PASS"
