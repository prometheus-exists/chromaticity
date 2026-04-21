import json

from chromaticity.audio import AudioFeatures
from chromaticity.glsl_parser import UniformInfo
from chromaticity.mapper import UniformMapper


def _features() -> AudioFeatures:
    return AudioFeatures(
        timestamp=1.0,
        sample_rate=44_100,
        hop_size=512,
        bands=(0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8),
        spectral_centroid=5_000.0,
        rms_energy=0.5,
        onset_strength=0.9,
        beat_phase=0.25,
        bpm=120.0,
    )


def test_default_mapping_heuristics():
    mapper = UniformMapper(
        uniform_infos=[
            UniformInfo(name="uSpeed", glsl_type="float", is_builtin=False),
            UniformInfo(name="uAmp", glsl_type="float", is_builtin=False),
            UniformInfo(name="uPhaseTime", glsl_type="float", is_builtin=False),
            UniformInfo(name="uFallback", glsl_type="float", is_builtin=False),
            UniformInfo(name="iTime", glsl_type="float", is_builtin=True),
        ]
    )
    values = mapper.map(_features())
    assert abs(values["uSpeed"] - 1.0) < 1e-6
    assert abs(values["uAmp"] - 0.5) < 1e-6
    assert abs(values["uPhaseTime"] - 0.25) < 1e-6
    assert values["uFallback"] >= 0.0
    assert values["iTime"] >= 0.0


def test_custom_mapping_json_round_trip(tmp_path):
    mapping_path = tmp_path / "shader.mapping.json"
    payload = {
        "schema_version": "0.1.0",
        "uniforms": {
            "uGain": {
                "audio_feature": "band_3",
                "scale": 2.0,
                "bias": 0.1,
                "smoothing": 0.0,
                "range": [0.0, 1.0],
            }
        },
    }
    mapping_path.write_text(json.dumps(payload))

    mapper = UniformMapper(str(mapping_path))
    values = mapper.map(_features())
    assert abs(values["uGain"] - 0.9) < 1e-6

