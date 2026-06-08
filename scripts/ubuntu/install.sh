#!/usr/bin/env bash
# Ubuntu 24.04 installer for VisoMaster-Fusion (CUDA 12.9 / cu129 stack).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PYTHON="${PYTHON:-python3.11}"
REQUIREMENTS="requirements_cu129.txt"

echo "=== VisoMaster Ubuntu installer ==="
echo "Project root: $ROOT"

# --- System dependency checks ---
missing=()
for cmd in git ffmpeg "$PYTHON"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        missing+=("$cmd")
    fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Missing system commands: ${missing[*]}"
    echo "Install with:"
    echo "  sudo apt update"
    echo "  sudo apt install -y git ffmpeg python3.11 python3.11-venv libxcb-cursor0 libxkbcommon-x11-0"
    exit 1
fi

if ! command -v ffplay >/dev/null 2>&1; then
    echo "WARN: ffplay not found. Live audio preview may not work."
    echo "      Ensure full ffmpeg package is installed."
fi

if ! command -v nvidia-smi >/dev/null 2>&1; then
    echo "WARN: nvidia-smi not found. GPU features will not work until NVIDIA driver is installed."
else
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
fi

# --- uv ---
if ! command -v uv >/dev/null 2>&1; then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # shellcheck disable=SC1091
    [[ -f "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"
fi

# --- venv ---
if [[ ! -d ".venv" ]]; then
    echo "Creating virtual environment..."
    uv venv --python "$PYTHON"
fi

# shellcheck disable=SC1091
source ".venv/bin/activate"

echo "Installing Python dependencies from $REQUIREMENTS..."
uv pip install -r "$REQUIREMENTS"

# --- UI codegen ---
bash "$ROOT/scripts/ubuntu/convert_ui.sh"

# --- Models ---
if [[ -f "download_models.py" ]]; then
    echo "Downloading models (this may take a while)..."
    python download_models.py
else
    echo "WARN: download_models.py not found."
fi

echo ""
echo "NOTE: If you migrated from Windows, clear incompatible TensorRT engine cache:"
echo "  rm -rf tensorrt-engines/ model_assets/liveportrait_onnx/*.trt"

echo "=== Install complete ==="
echo "Run GPU validation: ./scripts/ubuntu/validate_gpu.sh"
echo "Start application:  ./scripts/ubuntu/start.sh"
