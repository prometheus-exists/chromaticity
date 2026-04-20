import numpy as np


def compute_luminance(frame_rgba: np.ndarray) -> np.ndarray:
    """frame_rgba: (H, W, 4) float32 0-1. Returns (H, W) luminance."""
    return (
        0.2126 * frame_rgba[:, :, 0]
        + 0.7152 * frame_rgba[:, :, 1]
        + 0.0722 * frame_rgba[:, :, 2]
    )


def compute_cielab_stats(frame_rgba: np.ndarray) -> dict:
    """Returns dict with mean_L, mean_a, mean_b, std_a, std_b, mean_chroma."""
    from skimage.color import rgb2lab

    # H1 fix: clamp to [0,1] — f4 renderbuffer is unclamped; HDR shaders can exceed 1.0
    rgb = np.clip(frame_rgba[:, :, :3], 0.0, 1.0)
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
