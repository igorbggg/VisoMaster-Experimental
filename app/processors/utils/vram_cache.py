"""
Utilities for clearing GPU tensor caches that persist across frames.

These caches improve per-frame performance but can grow without bounds during
long playback sessions if not periodically cleared.
"""

from __future__ import annotations

import gc
from typing import TYPE_CHECKING

import torch

if TYPE_CHECKING:
    from app.processors.models_processor import ModelsProcessor


def clear_vr180_grid_caches() -> None:
    """Clear module-level VR180 equirectangular / perspective grid caches."""
    from app.processors.external.Equirec2Perspec_vr import clear_perspective_grid_cache
    from app.processors.external.Perspec2Equirec_vr import clear_vr_grid_caches

    clear_vr_grid_caches()
    clear_perspective_grid_cache()


def clear_denoiser_kv_cache() -> None:
    """Clear the ReF-LDM K/V extraction cache used during denoiser passes."""
    from app.processors.utils.ref_ldm_kv_embedding import cache_kv_module

    cache_kv_module.clear_cache()


def clear_session_vram_caches(models_processor: ModelsProcessor | None = None) -> None:
    """
    Release GPU tensor caches retained across frames without unloading ONNX models.
    Safe to call during playback or when stopping processing.
    """
    clear_vr180_grid_caches()
    clear_denoiser_kv_cache()

    if models_processor is not None:
        models_processor.face_detectors.clear_gpu_caches()
        models_processor.face_landmark_detectors.clear_gpu_caches()


def release_frame_gpu_memory(
    models_processor: ModelsProcessor | None = None,
    *,
    synchronize: bool = True,
    empty_cache: bool = False,
    clear_session_caches: bool = False,
) -> None:
    """
    Lightweight per-frame GPU memory release after frame processing completes.

    Runs Python GC to drop unreferenced tensors, optionally synchronizes CUDA
    and returns cached blocks to the driver.
    """
    gc.collect()
    if not torch.cuda.is_available():
        return
    if synchronize:
        torch.cuda.synchronize()
    if empty_cache:
        torch.cuda.empty_cache()
    if models_processor is not None and clear_session_caches:
        clear_session_vram_caches(models_processor)
