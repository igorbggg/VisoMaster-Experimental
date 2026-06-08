#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [[ -f ".venv/bin/activate" ]]; then
    # shellcheck disable=SC1091
    source ".venv/bin/activate"
elif command -v conda >/dev/null 2>&1; then
    # Optional conda fallback
    eval "$(conda shell.bash hook)"
    conda activate visomaster
else
    echo "ERROR: No .venv found and conda not available."
    echo "Run ./scripts/ubuntu/install.sh first."
    exit 1
fi

if [[ ! -f "app/ui/core/main_window.py" || ! -f "app/ui/core/media_rc.py" ]]; then
    echo "UI files missing. Running convert_ui.sh..."
    bash "$ROOT/scripts/ubuntu/convert_ui.sh"
fi

echo "Running VisoMaster..."
python main.py
