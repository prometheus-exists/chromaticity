import json
import os

import pytest


NEGATIVE_SHADER = os.path.join(
    os.path.dirname(__file__), "..", "test-shaders", "negative_test.glsl"
)
SINGLE_PASS_SHADER = os.path.join(
    os.path.dirname(__file__), "..", "test-shaders", "3sySRK.glsl"
)
BROKEN_GLSL = "void mainImage(out vec4 o, vec2 u) { THIS IS NOT VALID GLSL }"


def _run_probe(shader_path, output_path, itime_end=10.0, itime_step=2.0):
    from chromaticity.probe import probe_shader

    return probe_shader(
        shader_path=shader_path,
        output_path=output_path,
        itime_end=itime_end,
        itime_step=itime_step,
        resolution=(64, 64),
    )


def test_profile_schema(tmp_path):
    """Output JSON must have all required top-level keys and schema_version 1.0."""
    out = str(tmp_path / "schema_test.json")
    profile = _run_probe(NEGATIVE_SHADER, out)
    required_keys = {
        "schema_version",
        "shader_id",
        "shader_path",
        "probe_date",
        "probe_config",
        "itime_sensitivity",
        "uniforms_detected",
        "flags",
    }
    assert required_keys.issubset(profile.keys())
    assert profile["schema_version"] == "1.0"
    with open(out) as f:
        loaded = json.load(f)
    assert loaded["schema_version"] == "1.0"


def test_negative_case(tmp_path):
    """Static Mandelbrot: motion dissimilarity must be near zero (noise floor)."""
    pytest.importorskip("moderngl")
    pytest.importorskip("skimage")
    out = str(tmp_path / "negative.json")
    profile = _run_probe(NEGATIVE_SHADER, out)
    if profile["flags"]["compilation_error"]:
        pytest.skip(f"Shader compile failed: {profile['flags']['compilation_error']}")
    mean_dissim = profile["itime_sensitivity"]["motion"]["mean_dissimilarity"]
    assert (
        mean_dissim < 0.01
    ), f"Negative case had dissimilarity {mean_dissim:.4f} — probe has artefacts"


def test_compilation_gate(tmp_path):
    """Broken GLSL must set flags.compilation_error, not raise, and write valid JSON."""
    pytest.importorskip("moderngl")  # M2 fix: needs moderngl to attempt compilation
    broken = tmp_path / "broken.glsl"
    broken.write_text(BROKEN_GLSL)
    out = str(tmp_path / "broken.json")
    profile = _run_probe(str(broken), out, itime_end=2.0, itime_step=1.0)
    assert profile["flags"]["compilation_error"] is not None
    # C2 fix verification: output file must be valid JSON (no NaN)
    with open(out) as f:
        loaded = json.load(f)  # would raise if NaN written
    assert loaded["flags"]["compilation_error"] is not None
    assert loaded["itime_sensitivity"]["luminance"]["mean"] == []


def test_single_pass_responsive(tmp_path):
    """3sySRK metaballs must show non-zero motion over time."""
    pytest.importorskip("moderngl")
    pytest.importorskip("skimage")
    out = str(tmp_path / "3sySRK.json")
    profile = _run_probe(SINGLE_PASS_SHADER, out)
    if profile["flags"]["compilation_error"]:
        pytest.skip(f"Shader compile failed: {profile['flags']['compilation_error']}")
    mean_dissim = profile["itime_sensitivity"]["motion"]["mean_dissimilarity"]
    assert (
        mean_dissim > 0.01
    ), f"3sySRK showed no motion (dissimilarity={mean_dissim:.4f})"
