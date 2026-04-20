import argparse
import datetime
import json
import os

import numpy as np

from .glsl_parser import needs_ichannel0, parse_uniforms
from .metrics import (
    compute_cielab_stats,
    compute_luminance,
    compute_ssim_dissimilarity,
    possibly_incomplete,
    sensitivity_score,
)
from .profile import ShaderProfile, save_profile
from .renderer import render_frames

_EMPTY_LUMINANCE = {"mean": [], "std": 0.0, "range": [0.0, 0.0], "sensitivity_score": 0.0}
_EMPTY_COLOUR = {
    "mean_L": [], "mean_a": [], "mean_b": [],
    "std_a": [], "std_b": [], "mean_chroma": [],
    "colour_velocity": [], "sensitivity_score": 0.0,
}
_EMPTY_MOTION = {"ssim_dissimilarity": [], "mean_dissimilarity": 0.0, "sensitivity_score": 0.0}


def probe_shader(
    shader_path: str,
    output_path: str,
    itime_start: float = 0.0,
    itime_end: float = 60.0,
    itime_step: float = 1.0,
    resolution: tuple = (512, 512),
) -> ShaderProfile:
    shader_id = os.path.splitext(os.path.basename(shader_path))[0]

    with open(shader_path) as f:
        source = f.read()

    uniforms = parse_uniforms(source)
    uniform_names = [u.name for u in uniforms]
    multi_pass = False
    feedback = False
    ichannel0 = needs_ichannel0(source)

    itime_values = list(np.arange(itime_start, itime_end + itime_step * 0.5, itime_step))
    n = len(itime_values)

    frames, error = render_frames(source, itime_values, resolution=resolution)

    # --- C1/C2 fix: short-circuit on error (empty frames) ---
    if error is not None or not frames:
        profile: ShaderProfile = {
            "schema_version": "1.0",
            "shader_id": shader_id,
            "shader_path": shader_path,
            "probe_date": datetime.datetime.utcnow().isoformat(),
            "probe_config": {
                "resolution": list(resolution),
                "itime_start": itime_start,
                "itime_end": itime_end,
                "itime_step": itime_step,
                "warmup_frames": 0,
                "multi_pass": multi_pass,
                "feedback_loop": feedback,
            },
            "itime_sensitivity": {
                "luminance": _EMPTY_LUMINANCE,
                "colour": _EMPTY_COLOUR,
                "motion": _EMPTY_MOTION,
            },
            "uniforms_detected": uniform_names,
            "flags": {
                "multi_pass": multi_pass,
                "feedback_loop": feedback,
                "needs_ichannel0": ichannel0,
                "compilation_error": error,
                "warmup_frames_used": 0,
                "sweep_complete": False,
                "possibly_incomplete": False,
            },
        }
        os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
        # C2 fix: explicit NaN guard — raise immediately rather than write corrupt JSON
        save_profile(profile, output_path)
        print(f"Profile written (error): {output_path}")
        return profile

    # --- Normal path ---
    lum_series, lab_series, dissim_series = [], [], []
    valid_frames = [f for f in frames if f is not None]
    sweep_complete = len(valid_frames) == n

    for i, frame in enumerate(frames):
        if frame is None:
            lum_series.append(None)
            lab_series.append(None)
            dissim_series.append(0.0)
            continue
        lum = compute_luminance(frame)
        lum_series.append(float(lum.mean()))
        lab_series.append(compute_cielab_stats(frame))
        if i == 0 or frames[i - 1] is None:
            dissim_series.append(0.0)
        else:
            dissim_series.append(compute_ssim_dissimilarity(frame, frames[i - 1]))

    lum_clean = [v if v is not None else 0.0 for v in lum_series]
    mean_l = [s["mean_L"] if s else 0.0 for s in lab_series]
    mean_a = [s["mean_a"] if s else 0.0 for s in lab_series]
    mean_b = [s["mean_b"] if s else 0.0 for s in lab_series]
    std_a  = [s["std_a"]  if s else 0.0 for s in lab_series]
    std_b  = [s["std_b"]  if s else 0.0 for s in lab_series]
    chroma = [s["mean_chroma"] if s else 0.0 for s in lab_series]
    vel    = [0.0] + [abs(chroma[i] - chroma[i - 1]) for i in range(1, len(chroma))]

    # L1 fix: guard std for single-sample sweeps
    lum_arr = np.array(lum_clean)
    lum_std = float(np.std(lum_arr)) if len(lum_arr) > 1 else 0.0
    lum_range = [float(lum_arr.min()), float(lum_arr.max())] if len(lum_arr) > 0 else [0.0, 0.0]

    # H2 fix: motion sensitivity_score uses same formula as luminance/colour
    dissim_tail = dissim_series[1:] if len(dissim_series) > 1 else []

    profile = {
        "schema_version": "1.0",
        "shader_id": shader_id,
        "shader_path": shader_path,
        "probe_date": datetime.datetime.utcnow().isoformat(),
        "probe_config": {
            "resolution": list(resolution),
            "itime_start": itime_start,
            "itime_end": itime_end,
            "itime_step": itime_step,
            "warmup_frames": 0,
            "multi_pass": multi_pass,
            "feedback_loop": feedback,
        },
        "itime_sensitivity": {
            "luminance": {
                "mean": lum_clean,
                "std": lum_std,
                "range": lum_range,
                "sensitivity_score": sensitivity_score(lum_clean),
            },
            "colour": {
                "mean_L": mean_l,
                "mean_a": mean_a,
                "mean_b": mean_b,
                "std_a": std_a,
                "std_b": std_b,
                "mean_chroma": chroma,
                "colour_velocity": vel,
                "sensitivity_score": sensitivity_score(chroma),
            },
            "motion": {
                "ssim_dissimilarity": dissim_series,
                "mean_dissimilarity": float(np.mean(dissim_tail)) if dissim_tail else 0.0,
                # H2 fix: use same sensitivity_score formula, not mean_dissimilarity
                "sensitivity_score": sensitivity_score(dissim_tail) if dissim_tail else 0.0,
            },
        },
        "uniforms_detected": uniform_names,
        "flags": {
            "multi_pass": multi_pass,
            "feedback_loop": feedback,
            "needs_ichannel0": ichannel0,
            "compilation_error": error,
            "warmup_frames_used": 0,
            "sweep_complete": sweep_complete,
            "possibly_incomplete": possibly_incomplete(chroma),
        },
    }

    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    save_profile(profile, output_path)
    print(f"Profile written: {output_path}")
    return profile


def main():
    parser = argparse.ArgumentParser(description="Chromaticity render-probe analyser")
    parser.add_argument("--shader", required=True, help="Path to GLSL shader file")
    parser.add_argument("--output", required=True, help="Output JSON profile path")
    parser.add_argument("--itime-start", type=float, default=0.0)
    parser.add_argument("--itime-end", type=float, default=60.0)
    parser.add_argument("--itime-step", type=float, default=1.0)
    parser.add_argument("--width", type=int, default=512)
    parser.add_argument("--height", type=int, default=512)
    args = parser.parse_args()

    probe_shader(
        shader_path=args.shader,
        output_path=args.output,
        itime_start=args.itime_start,
        itime_end=args.itime_end,
        itime_step=args.itime_step,
        resolution=(args.width, args.height),
    )


if __name__ == "__main__":
    main()
