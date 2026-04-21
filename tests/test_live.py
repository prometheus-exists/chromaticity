from chromaticity.audio import AudioFeatureBuffer, AudioFeatures
from chromaticity.live import run_live


class _FakeBackend:
    def __init__(self) -> None:
        self.frames = 0

    def should_close(self) -> bool:
        return False

    def render_frame(
        self,
        uniforms: dict[str, float],
        frame_index: int,
        delta_seconds: float,
    ) -> None:
        assert "iTime" in uniforms
        self.frames += 1

    def close(self) -> None:
        return None


class _FakeAudioSource:
    def start(self, feature_buffer: AudioFeatureBuffer) -> None:
        feature_buffer.update(AudioFeatures.silence())

    def close(self) -> None:
        return None


def test_run_live_headless_smoke(monkeypatch):
    backend = _FakeBackend()
    monkeypatch.setattr(
        "chromaticity.live._create_backend",
        lambda shader_source, uniform_infos, width, height, fullscreen, headless: backend,
    )
    monkeypatch.setattr(
        "chromaticity.live._create_audio_source",
        lambda audio_device: (_FakeAudioSource(), None),
    )

    stats = run_live(
        "test-shaders/curl_flow.glsl",
        duration_seconds=1.0,
        fps=20,
        headless=True,
    )
    assert stats.frames_rendered > 0
    assert backend.frames == stats.frames_rendered
