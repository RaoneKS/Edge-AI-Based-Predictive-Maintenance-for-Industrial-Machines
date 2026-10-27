#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prefer an explicit override, then a system PATH install, then known local
# Lite/Standard installations. Quartus Lite 25.1 is used for DE10 builds here.
quartus_sh_bin="${QUARTUS_SH:-}"
if [[ -z "$quartus_sh_bin" ]]; then
  if command -v quartus_sh >/dev/null 2>&1; then
    quartus_sh_bin="$(command -v quartus_sh)"
  elif [[ -x "$HOME/intelFPGA/25.1lite/quartus/bin/quartus_sh" ]]; then
    quartus_sh_bin="$HOME/intelFPGA/25.1lite/quartus/bin/quartus_sh"
  elif [[ -x "$HOME/intelFPGA/23.1std/quartus/bin/quartus_sh" ]]; then
    quartus_sh_bin="$HOME/intelFPGA/23.1std/quartus/bin/quartus_sh"
  else
    echo "ERROR: quartus_sh not found. Set QUARTUS_SH to your Quartus executable." >&2
    exit 127
  fi
fi

if [[ ! -x "$quartus_sh_bin" ]]; then
  echo "ERROR: QUARTUS_SH is not executable: $quartus_sh_bin" >&2
  exit 127
fi

python_bin="${PYTHON_BIN:-}"
if [[ -z "$python_bin" ]]; then
  if [[ -x "$project_dir/../../.venv/bin/python3" ]]; then
    python_bin="$project_dir/../../.venv/bin/python3"
  else
    python_bin="$(command -v python3)"
  fi
fi

cd "$project_dir"
"$python_bin" "$project_dir/../../verification/scripts/prepare_de10_model_data.py"
"$quartus_sh_bin" --flow compile de10_standard_hw
