#!/usr/bin/env bash
# GPU smoke tests for Ubuntu 24.04 + NVIDIA RTX 5080 (CUDA 12.9 / cu129 stack).
# Run from project root after install.sh, with venv activated or via install path.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PASS=0
FAIL=0
WARN=0

ok()   { echo "[PASS] $*"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $*"; FAIL=$((FAIL + 1)); }
warn() { echo "[WARN] $*"; WARN=$((WARN + 1)); }

echo "=== VisoMaster GPU Validation (Ubuntu 24.04 + RTX 5080) ==="
echo "Host: $(uname -a)"
echo ""

# --- 1. nvidia-smi ---
echo "--- 1. NVIDIA driver ---"
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi
    GPU_NAME="$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
    DRIVER_VER="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)"
    CUDA_VER="$(nvidia-smi | grep -o 'CUDA Version: [0-9.]*' | awk '{print $3}')"
    ok "nvidia-smi: GPU=$GPU_NAME driver=$DRIVER_VER CUDA=$CUDA_VER"
    if [[ "$GPU_NAME" != *"5080"* ]]; then
        warn "Expected RTX 5080, found: $GPU_NAME"
    fi
else
    fail "nvidia-smi not found — install NVIDIA driver"
fi

# --- 2. ffmpeg NVENC ---
echo ""
echo "--- 2. FFmpeg NVENC ---"
if command -v ffmpeg >/dev/null 2>&1; then
    if ffmpeg -encoders 2>/dev/null | grep -q hevc_nvenc; then
        ok "ffmpeg has hevc_nvenc encoder"
    else
        warn "hevc_nvenc not available — SDR recording will use libx265 fallback"
    fi
    if command -v ffplay >/dev/null 2>&1; then
        ok "ffplay available"
    else
        warn "ffplay not found — live audio preview disabled"
    fi
else
    fail "ffmpeg not found"
fi

# --- 3. Python venv ---
echo ""
echo "--- 3. Python environment ---"
if [[ -f ".venv/bin/activate" ]]; then
    # shellcheck disable=SC1091
    source ".venv/bin/activate"
    ok "venv activated: $(python --version)"
else
    fail ".venv not found — run install.sh"
fi

# --- 4. PyTorch CUDA ---
echo ""
echo "--- 4. PyTorch CUDA ---"
python - <<'PY' && ok "PyTorch CUDA check" || fail "PyTorch CUDA check"
import torch
assert torch.cuda.is_available(), "torch.cuda.is_available() is False"
name = torch.cuda.get_device_name(0)
print(f"  device: {name}")
print(f"  capability: {torch.cuda.get_device_capability(0)}")
# Smoke tensor op
x = torch.randn(4, 4, device="cuda")
y = x @ x
print(f"  matmul ok: {y.shape}")
PY

# --- 5. ONNX Runtime ---
echo ""
echo "--- 5. ONNX Runtime providers ---"
python - <<'PY' && ok "ONNX Runtime providers" || fail "ONNX Runtime providers"
import onnxruntime as ort
providers = ort.get_available_providers()
print(f"  providers: {providers}")
assert "CUDAExecutionProvider" in providers, "CUDAExecutionProvider missing"
PY

# --- 6. TensorRT ---
echo ""
echo "--- 6. TensorRT ---"
python - <<'PY' && ok "TensorRT import" || fail "TensorRT import"
import tensorrt as trt
from packaging import version
ver = trt.__version__
print(f"  tensorrt version: {ver}")
assert version.parse(ver) >= version.parse("10.2.0"), "TensorRT < 10.2.0"
PY

# --- 7. TensorRT EP (optional) ---
echo ""
echo "--- 7. TensorRT Execution Provider ---"
python - <<'PY'
import onnxruntime as ort
providers = ort.get_available_providers()
if "TensorrtExecutionProvider" in providers:
    print("  TensorrtExecutionProvider: available")
    raise SystemExit(0)
else:
    print("  TensorrtExecutionProvider: NOT available")
    raise SystemExit(1)
PY
if [[ $? -eq 0 ]]; then ok "TensorRT EP"; else warn "TensorRT EP not listed (may still work via pip tensorrt)"; fi

# --- 8. UI codegen ---
echo ""
echo "--- 8. UI generated files ---"
if [[ -f "app/ui/core/main_window.py" && -f "app/ui/core/media_rc.py" ]]; then
    ok "main_window.py and media_rc.py present"
else
    fail "UI files missing — run convert_ui.sh"
fi

# --- 9. Optional TRT plugin ---
echo ""
echo "--- 9. TensorRT custom plugin (LivePortrait) ---"
PLUGIN="model_assets/libgrid_sample_3d_plugin.so"
if [[ -f "$PLUGIN" ]]; then
    ok "Found $PLUGIN"
    python - <<PY
import ctypes
ctypes.CDLL("$PLUGIN", mode=ctypes.RTLD_GLOBAL)
print("  plugin load: OK")
PY
else
    warn "$PLUGIN missing — TensorRT-Engine + Human-Face LivePortrait will fail"
fi

# --- 10. Optional assets ---
echo ""
echo "--- 10. Optional model assets ---"
for f in \
    "model_assets/liveportrait_onnx/lip_array.pkl" \
    "model_assets/meanshape_68.pkl"
do
    if [[ -f "$f" ]]; then ok "Found $f"; else warn "Missing $f"; fi
done

# --- Summary ---
echo ""
echo "=== Summary: PASS=$PASS FAIL=$FAIL WARN=$WARN ==="
if [[ $FAIL -gt 0 ]]; then
    echo "Validation FAILED — fix FAIL items before production use."
    exit 1
fi
echo "Validation passed (with $WARN warnings). Ready for functional testing."
exit 0
