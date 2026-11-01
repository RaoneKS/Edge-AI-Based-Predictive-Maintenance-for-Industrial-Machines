#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$project_dir/../../.." && pwd)"
log_dir="$project_dir/output_files/acceptance_logs"
mkdir -p "$log_dir"

quartus_sh_bin="${QUARTUS_SH:-}"
if [[ -z "$quartus_sh_bin" ]]; then
  if command -v quartus_sh >/dev/null 2>&1; then
    quartus_sh_bin="$(command -v quartus_sh)"
  elif [[ -x "$HOME/intelFPGA/25.1lite/quartus/bin/quartus_sh" ]]; then
    quartus_sh_bin="$HOME/intelFPGA/25.1lite/quartus/bin/quartus_sh"
  elif [[ -x "$HOME/intelFPGA/23.1std/quartus/bin/quartus_sh" ]]; then
    quartus_sh_bin="$HOME/intelFPGA/23.1std/quartus/bin/quartus_sh"
  else
    echo "ERROR: quartus_sh not found; set QUARTUS_SH=/path/to/quartus_sh" >&2
    exit 127
  fi
fi
if [[ ! -x "$quartus_sh_bin" ]]; then
  echo "ERROR: quartus_sh is not executable: $quartus_sh_bin" >&2
  exit 127
fi

quartus_bin_dir="$(cd "$(dirname "$quartus_sh_bin")" && pwd)"
quartus_sta_bin="${QUARTUS_STA:-$quartus_bin_dir/quartus_sta}"
if [[ ! -x "$quartus_sta_bin" ]]; then
  echo "ERROR: quartus_sta not found next to quartus_sh; set QUARTUS_STA." >&2
  exit 127
fi

python_bin="${PYTHON_BIN:-}"
if [[ -z "$python_bin" ]]; then
  if [[ -x "$repo_root/.venv/bin/python3" ]]; then
    python_bin="$repo_root/.venv/bin/python3"
  else
    python_bin="$(command -v python3)"
  fi
fi

cd "$project_dir"
echo "PROJECT=de10_systolic_cnn"
echo "DEVICE=5CSXFC6D6F31C6"
echo "TOP_LEVEL=de10_systolic_cnn_top"
echo "QUARTUS_SH=$quartus_sh_bin"
echo "QUARTUS_STA=$quartus_sta_bin"
echo "BRANCH=$(git -C "$repo_root" branch --show-current 2>/dev/null || echo unknown)"
echo "COMMIT=$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || echo unknown)"

echo
echo "========== PREPARE MODEL ROMS =========="
"$python_bin" "$repo_root/verification/scripts/prepare_de10_model_data.py"

echo
echo "========== QUARTUS FULL COMPILE =========="
set +e
"$quartus_sh_bin" --flow compile de10_systolic_cnn 2>&1 | tee "$log_dir/quartus_compile.log"
compile_status=${PIPESTATUS[0]}
set -e
echo "QUARTUS_COMPILE_EXIT_STATUS=$compile_status"
if [[ $compile_status -ne 0 ]]; then
  echo "CLASSIFICATION=NOT MAPPABLE TO DE10 — analysis/synthesis, fit, or assembler failed; inspect compile log."
  exit "$compile_status"
fi

echo
echo "========== TIMEQUEST TIMING REPORTS =========="
set +e
"$quartus_sta_bin" -t "$project_dir/run_sta.tcl" -c de10_systolic_cnn 2>&1 | tee "$log_dir/quartus_sta.log"
sta_status=${PIPESTATUS[0]}
set -e
echo "QUARTUS_STA_EXIT_STATUS=$sta_status"
if [[ $sta_status -ne 0 ]]; then
  echo "CLASSIFICATION=TIMING CONSTRAINT NOT VERIFIED"
  exit "$sta_status"
fi

echo
echo "========== GENERATED FILES =========="
find "$project_dir/output_files" -maxdepth 2 -type f \
  \( -name '*.sof' -o -name '*.rpt' -o -name '*.sta.rpt' -o -path '*/sta_reports/*' \) \
  -printf '%p (%s bytes)\n' | sort
if [[ ! -s "$project_dir/output_files/de10_systolic_cnn.sof" ]]; then
  echo "WARNING: .sof file was not found. Programming-file generation is not verified."
  exit 1
fi

echo
echo "CLASSIFICATION=DE10 build and timing scripts completed; inspect STA reports for 20 ns clock, unconstrained paths, setup and hold slack."
echo "PROGRAMMING_FILE=$project_dir/output_files/de10_systolic_cnn.sof"
