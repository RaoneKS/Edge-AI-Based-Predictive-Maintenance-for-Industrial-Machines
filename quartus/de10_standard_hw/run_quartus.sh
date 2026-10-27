#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
quartus_sh_bin="${QUARTUS_SH:-/home/raone/intelFPGA/23.1std/quartus/bin/quartus_sh}"
python_bin="${PYTHON_BIN:-}"
if [ -z "$python_bin" ]; then
  if [ -x "$project_dir/../../.venv/bin/python3" ]; then
    python_bin="$project_dir/../../.venv/bin/python3"
  else
    python_bin="python3"
  fi
fi
cd "$project_dir"
"$python_bin" "$project_dir/../../verification/scripts/prepare_de10_model_data.py"
"$quartus_sh_bin" --flow compile de10_standard_hw
