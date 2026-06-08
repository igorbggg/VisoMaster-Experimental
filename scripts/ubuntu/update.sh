#!/usr/bin/env bash
# Update code and cu129 dependencies on Ubuntu.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

REQUIREMENTS="requirements_cu129.txt"

if [[ ! -f ".venv/bin/activate" ]]; then
    echo "ERROR: .venv not found. Run ./scripts/ubuntu/install.sh first."
    exit 1
fi

# shellcheck disable=SC1091
source ".venv/bin/activate"

echo "Fetching latest code..."
git fetch origin
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
echo "Current branch: $CURRENT_BRANCH"
read -r -p "Reset hard to origin/$CURRENT_BRANCH? [y/N] " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    git reset --hard "origin/$CURRENT_BRANCH"
fi

echo "Updating Python dependencies..."
uv pip install -r "$REQUIREMENTS"

echo "Refreshing models..."
python download_models.py

echo "Regenerating UI files..."
bash "$ROOT/scripts/ubuntu/convert_ui.sh"

echo "Update complete. Consider clearing tensorrt-engines/ if TRT or GPU changed:"
echo "  rm -rf tensorrt-engines/ model_assets/liveportrait_onnx/*.trt"
