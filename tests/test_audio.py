import numpy as np

from chromaticity.audio import analyze_signal


def _click_train(
    bpm: float,
    duration_seconds: float,
    sample_rate: int = 44_100,
) -> np.ndarray:
    total_samples = int(duration_seconds * sample_rate)
    signal = np.zeros(total_samples, dtype=np.float32)
    period = int(round((60.0 / bpm) * sample_rate))
    click = np.hanning(128).astype(np.float32)
    for start in range(0, total_samples - len(click), period):
        signal[start : start + len(click)] += click
    return signal


def test_click_train_tempo_detection():
    signal = _click_train(bpm=120.0, duration_seconds=8.0)
    features = analyze_signal(signal)
    stable_bpms = [frame.bpm for frame in features if frame.timestamp > 4.0 and frame.bpm > 0.0]
    assert stable_bpms, "Tempo tracker never produced a BPM estimate"
    detected_bpm = stable_bpms[-1]
    assert abs(detected_bpm - 120.0) / 120.0 <= 0.05
    assert any(frame.onset_strength > 0.0 for frame in features)

