from __future__ import annotations

import json
import math
import re
import time
from dataclasses import dataclass

from .audio import AudioFeatures
from .glsl_parser import UniformInfo


@dataclass(slots=True)
class UniformMapping:
    audio_feature: str
    scale: float = 1.0
    bias: float = 0.0
    smoothing: float = 0.0
    value_range: tuple[float, float] | None = None


def _clamp(value: float, limits: tuple[float, float] | None) -> float:
    if limits is None:
        return value
    low, high = limits
    return max(low, min(high, value))


def _float_pair(value: object) -> tuple[float, float] | None:
    if not isinstance(value, list | tuple) or len(value) != 2:
        return None
    return float(value[0]), float(value[1])


class UniformMapper:
    """Map audio features onto shader uniform values."""

    def __init__(
        self,
        mapping_path: str | None = None,
        uniform_infos: list[UniformInfo] | None = None,
    ) -> None:
        self._uniform_infos = uniform_infos or []
        self._uniform_by_name = {info.name: info for info in self._uniform_infos}
        self._start_time = time.perf_counter()
        self._smoothed_values: dict[str, float] = {}
        self._mappings: dict[str, UniformMapping] = {}

        if mapping_path is not None:
            self._mappings.update(self._load_mapping_file(mapping_path))

        if self._uniform_infos:
            for info in self._uniform_infos:
                if info.glsl_type not in {"float", "vec2", "vec3", "vec4", "int"}:
                    continue
                self._mappings.setdefault(info.name, self._default_mapping_for_uniform(info.name))
        elif not self._mappings:
            self._mappings["iTime"] = self._default_mapping_for_uniform("iTime")

    @property
    def mappings(self) -> dict[str, UniformMapping]:
        return dict(self._mappings)

    def map(self, features: AudioFeatures) -> dict[str, float]:
        values: dict[str, float] = {}
        for uniform_name, mapping in self._mappings.items():
            raw = self._feature_value(mapping.audio_feature, features)
            raw = raw * mapping.scale + mapping.bias
            smoothed = self._apply_smoothing(uniform_name, raw, mapping.smoothing)
            values[uniform_name] = _clamp(smoothed, mapping.value_range)
        values["iTime"] = time.perf_counter() - self._start_time
        return values

    def _apply_smoothing(self, uniform_name: str, value: float, smoothing: float) -> float:
        smoothing = max(0.0, min(1.0, smoothing))
        previous = self._smoothed_values.get(uniform_name, value)
        smoothed = previous * smoothing + value * (1.0 - smoothing)
        self._smoothed_values[uniform_name] = smoothed
        return smoothed

    def _feature_value(self, feature_name: str, features: AudioFeatures) -> float:
        name = feature_name.lower()
        if name.startswith("band_"):
            index = int(name.split("_", 1)[1])
            if 0 <= index < len(features.bands):
                return float(features.bands[index])
            return 0.0
        if name in {"rms", "rms_energy", "energy"}:
            return float(features.rms_energy)
        if name in {"spectral_centroid", "centroid"}:
            nyquist = max(1.0, features.sample_rate / 2.0)
            return float(features.spectral_centroid / nyquist)
        if name in {"onset", "onset_strength", "spectral_flux"}:
            return float(features.onset_strength)
        if name in {"beat_phase", "phase"}:
            return float(features.beat_phase)
        if name in {"bpm"}:
            return float(features.bpm)
        if name in {"tempo", "tempo_norm"}:
            return float(features.bpm / 120.0) if features.bpm > 0.0 else 0.0
        if name in {"beat_pulse"}:
            return float(
                max(0.0, 0.5 - 0.5 * math.cos(2.0 * math.pi * features.beat_phase))
            )
        if name == "itime":
            return time.perf_counter() - self._start_time
        return time.perf_counter() - self._start_time

    def _load_mapping_file(self, mapping_path: str) -> dict[str, UniformMapping]:
        with open(mapping_path) as handle:
            payload = json.load(handle)
        uniforms = payload.get("uniforms", {})
        mappings: dict[str, UniformMapping] = {}
        for uniform_name, raw in uniforms.items():
            if not isinstance(raw, dict):
                continue
            mapping = self._parse_mapping_record(uniform_name, raw)
            mappings[uniform_name] = mapping
        return mappings

    def _parse_mapping_record(self, uniform_name: str, raw: dict[str, object]) -> UniformMapping:
        if "audio_feature" in raw:
            return UniformMapping(
                audio_feature=str(raw["audio_feature"]),
                scale=float(raw.get("scale", 1.0)),
                bias=float(raw.get("bias", 0.0)),
                smoothing=float(raw.get("smoothing", 0.0)),
                value_range=_float_pair(raw.get("range")),
            )

        user_override = raw.get("user_override")
        if isinstance(user_override, dict) and "audio_feature" in user_override:
            return UniformMapping(
                audio_feature=str(user_override["audio_feature"]),
                scale=float(user_override.get("scale", user_override.get("sensitivity", 1.0))),
                bias=float(user_override.get("bias", 0.0)),
                smoothing=float(user_override.get("smoothing", 0.0)),
                value_range=_float_pair(raw.get("probed_range") or raw.get("range")),
            )

        suggested = raw.get("suggested_audio_feature")
        if suggested:
            return UniformMapping(
                audio_feature=self._normalise_profile_feature(str(suggested)),
                scale=float(raw.get("sensitivity", 1.0)),
                bias=float(raw.get("bias", 0.0)),
                smoothing=float(raw.get("smoothing", 0.0)),
                value_range=_float_pair(raw.get("probed_range") or raw.get("range")),
            )

        return self._default_mapping_for_uniform(uniform_name)

    def _normalise_profile_feature(self, feature_name: str) -> str:
        mapping = {
            "rms_energy": "rms",
            "sub_bass_energy": "band_0",
            "spectral_flux": "onset_strength",
            "beat_pulse": "beat_phase",
            "tempo": "tempo",
            "onset": "onset_strength",
        }
        return mapping.get(feature_name, feature_name)

    def _default_mapping_for_uniform(self, uniform_name: str) -> UniformMapping:
        lowered = uniform_name.lower()
        if uniform_name == "iTime":
            return UniformMapping(audio_feature="iTime")
        if re.search(r"(phase|time|beat)", lowered):
            return UniformMapping(audio_feature="beat_phase")
        if re.search(r"(speed|freq|rate|tempo)", lowered):
            return UniformMapping(audio_feature="tempo")
        if re.search(r"(amp|loud|gain|energy|level|volume)", lowered):
            return UniformMapping(audio_feature="rms")
        # Frequency-split heuristics (Fletcher's insight: lows=slow, highs=fast)
        # Low-frequency / bass-heavy names → sub_bass band (kick, slow movers)
        if re.search(r"(bass|kick|sub|low|deep|throb|pulse|thump)", lowered):
            return UniformMapping(audio_feature="band_0", smoothing=0.85)  # heavy smoothing = slow response
        # High-frequency names → presence/air bands (hi-hats, fast detail)
        if re.search(r"(high|treble|crisp|air|detail|shimmer|sparkle|bright|sharp|edge)", lowered):
            return UniformMapping(audio_feature="band_6", smoothing=0.1)   # low smoothing = fast response
        # Mid/snare names → onset strength (snappy transients)
        if re.search(r"(mid|snare|hit|snap|crack|punch|attack|transient)", lowered):
            return UniformMapping(audio_feature="onset_strength", smoothing=0.3)
        # Brightness / luminance → broadband RMS
        if re.search(r"(bright|glow|lum|light|bloom|shine)", lowered):
            return UniformMapping(audio_feature="rms", smoothing=0.5)
        return UniformMapping(audio_feature="iTime")
