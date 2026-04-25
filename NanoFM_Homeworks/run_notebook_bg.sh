#!/usr/bin/env bash
#SBATCH --job-name=nanofm_notebook
#SBATCH --time=06:00:00
#SBATCH --account=cs-503
#SBATCH --qos=cs-503
#SBATCH --gres=gpu:1
#SBATCH --mem=64G
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --output=slurm-%x-%j.out
#SBATCH --error=slurm-%x-%j.err

set -euo pipefail

# Submit with:
#   sbatch run_notebook_bg.sh [notebook_path]
# Example:
#   sbatch run_notebook_bg.sh notebooks/CS503_FM_part4_nanoFlowMatching.ipynb

SCRIPT_DIR="${SLURM_SUBMIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
cd "$SCRIPT_DIR"

NOTEBOOK_PATH="${1:-notebooks/CS503_FM_part4_nanoFlowMatching.ipynb}"

if [[ ! -f "$NOTEBOOK_PATH" ]]; then
  echo "Error: notebook not found: $NOTEBOOK_PATH" >&2
  exit 1
fi

LOG_DIR="logs"
mkdir -p "$LOG_DIR"

NOTEBOOK_BASENAME="$(basename "$NOTEBOOK_PATH" .ipynb)"
JOB_ID="${SLURM_JOB_ID:-manual}"
LOG_FILE="$LOG_DIR/${NOTEBOOK_BASENAME}_${JOB_ID}.log"

echo "SLURM job id: ${SLURM_JOB_ID:-N/A}" | tee -a "$LOG_FILE"
echo "Running notebook: $NOTEBOOK_PATH" | tee -a "$LOG_FILE"
echo "Working directory: $PWD" | tee -a "$LOG_FILE"

# Resolve conda executable once.
if command -v conda >/dev/null 2>&1; then
  CONDA_BIN="$(command -v conda)"
else
  echo "Error: conda command not found in PATH." | tee -a "$LOG_FILE"
  exit 1
fi

echo "Conda executable: $CONDA_BIN" | tee -a "$LOG_FILE"
echo "Notebook runner python (nanofm env):" | tee -a "$LOG_FILE"
"$CONDA_BIN" run -n nanofm python -c 'import sys; print(sys.executable)' 2>&1 | tee -a "$LOG_FILE"

# Execute notebook and write outputs into the same .ipynb file using jupyter execute.
# Ensure nbclient is available; it provides the jupyter-execute entrypoint.
if ! "$CONDA_BIN" run -n nanofm python -c 'import importlib.util, sys; sys.exit(0 if importlib.util.find_spec("nbclient") else 1)'; then
  echo "nbclient not found in nanofm env; installing..." | tee -a "$LOG_FILE"
  "$CONDA_BIN" run -n nanofm python -m pip install nbclient 2>&1 | tee -a "$LOG_FILE"
fi

JUPYTER_EXECUTE="$("$CONDA_BIN" run -n nanofm python -c 'import os, sys; print(os.path.join(sys.prefix, "bin", "jupyter-execute"))' | tr -d '\r')"

if [[ ! -x "$JUPYTER_EXECUTE" ]]; then
  echo "Error: jupyter-execute not found or not executable at $JUPYTER_EXECUTE" | tee -a "$LOG_FILE"
  exit 1
fi

"$JUPYTER_EXECUTE" \
  --inplace \
  --timeout=-1 \
  --kernel_name=nanofm \
  "$NOTEBOOK_PATH" 2>&1 | tee -a "$LOG_FILE"

echo "Notebook execution finished successfully." | tee -a "$LOG_FILE"

