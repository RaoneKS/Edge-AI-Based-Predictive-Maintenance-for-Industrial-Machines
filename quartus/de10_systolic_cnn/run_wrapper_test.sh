#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$project_dir/../.." && pwd)"
build_dir="$project_dir/sim"
mkdir -p "$build_dir"

python_bin="${PYTHON_BIN:-}"
if [[ -z "$python_bin" ]]; then
  if [[ -x "$repo_root/.venv/bin/python3" ]]; then
    python_bin="$repo_root/.venv/bin/python3"
  else
    python_bin="$(command -v python3)"
  fi
fi
command -v iverilog >/dev/null || { echo "ERROR: iverilog is required" >&2; exit 127; }
command -v vvp >/dev/null || { echo "ERROR: vvp is required" >&2; exit 127; }

"$python_bin" "$repo_root/verification/scripts/prepare_de10_model_data.py"
iverilog -g2012 -s tb_de10_systolic_cnn_top -I"$repo_root/rtl" \
  "$repo_root/rtl/pkg_accelerator.sv" \
  "$repo_root/rtl/mac_unit.sv" \
  "$repo_root/rtl/systolic_array.sv" \
  "$repo_root/rtl/cnn_systolic_adapter.sv" \
  "$repo_root/rtl/cnn_inference_top.sv" \
  "$project_dir/de10_systolic_cnn_top.sv" \
  "$project_dir/tb_de10_systolic_cnn_top.sv" \
  -o "$build_dir/de10_wrapper.vvp" 2>&1 | tee "$build_dir/compile.log"

(
  cd "$project_dir"
  vvp "$build_dir/de10_wrapper.vvp" 2>&1 | tee "$build_dir/run.log"
)
grep -q "DE10_SYSTOLIC_CNN_WRAPPER_TEST_PASS" "$build_dir/run.log"
echo "DE10_SYSTOLIC_CNN_WRAPPER_REGRESSION_PASS"
