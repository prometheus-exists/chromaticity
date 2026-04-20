import numpy as np


def _sanitise(frame_rgba: np.ndarray) -> np.ndarray:
    """Replace NaN/Inf with 0.0 and clamp to [0,1]. Needed for shaders with
    divide-by-zero or 0/0 in their math (e.g. reflective tunnel shaders)."""
    out = np.nan_to_num(frame_rgba, nan=0.0, posinf=1.0, neginf=0.0)
    return np.clip(out, 0.0, 1.0)


def compute_luminance(frame_rgba: np.ndarray) -> np.ndarray:
    """frame_rgba: (H, W, 4) float32 0-1. Returns (H, W) luminance."""
    f = _sanitise(frame_rgba)
    return (
        0.2126 * f[:, :, 0]
        + 0.7152 * f[:, :, 1]
        + 0.0722 * f[:, :, 2]
    )


def compute_cielab_stats(frame_rgba: np.ndarray) -> dict:
    """Returns dict with mean_L, mean_a, mean_b, std_a, std_b, mean_chroma."""
    from skimage.color import rgb2lab

    # H1 fix + NaN guard: sanitise before conversion
    rgb = _sanitise(frame_rgba)[:, :, :3]
    lab = rgb2lab(rgb)
    a, b = lab[:, :, 1], lab[:, :, 2]
    return {
        "mean_L": float(lab[:, :, 0].mean()),
        "mean_a": float(a.mean()),
        "mean_b": float(b.mean()),
        "std_a": float(a.std()),
        "std_b": float(b.std()),
        "mean_chroma": float(np.sqrt(a**2 + b**2).mean()),
    }


def compute_ssim_dissimilarity(frame_t: np.ndarray, frame_tm1: np.ndarray) -> float:
    """1 - SSIM between consecutive greyscale frames."""
    from skimage.metrics import structural_similarity as ssim

    lum_t = compute_luminance(frame_t)
    lum_tm1 = compute_luminance(frame_tm1)
    score = ssim(lum_t, lum_tm1, data_range=1.0)
    return float(1.0 - score)


def sensitivity_score(series: list[float]) -> float:
    arr = np.array(series, dtype=float)
    return float(np.std(arr) / (np.mean(np.abs(arr)) + 1e-6))


def possibly_incomplete(series: list[float]) -> bool:
    arr = np.array(series, dtype=float)
    if len(arr) < 10:
        return False
    return float(np.std(arr[-10:])) / (float(np.std(arr)) + 1e-6) > 0.5
