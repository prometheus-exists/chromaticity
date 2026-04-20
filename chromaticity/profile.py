from typing import Optional, TypedDict
import datetime
import json


class ProbeConfig(TypedDict):
    resolution: list[int]
    itime_start: float
    itime_end: float
    itime_step: float
    warmup_frames: int
    multi_pass: bool
    feedback_loop: bool


class LuminanceSensitivity(TypedDict):
    mean: list[float]
    std: float
    range: list[float]
    sensitivity_score: float


class ColourSensitivity(TypedDict):
    mean_L: list[float]
    mean_a: list[float]
    mean_b: list[float]
    std_a: list[float]
    std_b: list[float]
    mean_chroma: list[float]
    colour_velocity: list[float]
    sensitivity_score: float


class MotionSensitivity(TypedDict):
    ssim_dissimilarity: list[float]
    mean_dissimilarity: float
    sensitivity_score: float


class ITimeSensitivity(TypedDict):
    luminance: LuminanceSensitivity
    colour: ColourSensitivity
    motion: MotionSensitivity


class ProfileFlags(TypedDict):
    multi_pass: bool
    feedback_loop: bool
    needs_ichannel0: bool
    compilation_error: Optional[str]
    warmup_frames_used: int
    sweep_complete: bool
    possibly_incomplete: bool


class ShaderProfile(TypedDict):
    schema_version: str
    shader_id: str
    shader_path: str
    probe_date: str
    probe_config: ProbeConfig
    itime_sensitivity: ITimeSensitivity
    uniforms_detected: list[str]
    flags: ProfileFlags


def save_profile(profile: ShaderProfile, path: str) -> None:
    with open(path, "w") as f:
        json.dump(profile, f, indent=2)


def load_profile(path: str) -> ShaderProfile:
    with open(path) as f:
        return json.load(f)
