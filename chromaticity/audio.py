from __future__ import annotations

import math
import threading
import warnings
from collections import deque
from dataclasses import dataclass, field
from typing import Any

import numpy as np


DEFAULT_SAMPLE_RATE = 44_100
DEFAULT_HOP_SIZE = 512
DEFAULT_WINDOW_SIZE = 2_048
DEFAULT_BAND_COUNT = 8
DEFAULT_MIN_BPM = 60.0
DEFAULT_MAX_BPM = 200.0
_BAND_LABELS = (
    "sub_bass",
    "bass",
    "low_mid",
    "mid",
    "high_mid",
    "presence",
    "air",
    "ultra",
)


@dataclass(slots=True)
class AudioFeatures:
    """Feature vector produced for each analysis hop."""

    timestamp: float
    sample_rate: int
    hop_size: int
    bands: tuple[float, ...]
    spectral_centroid: float
    rms_energy: float
    onset_strength: float
    beat_phase: float
    bpm: float
    tempo_confidence: float  # 0.0 = unstable/unknown, 1.0 = very stable

    @classmethod
    def silence(
        cls,
        sample_rate: int = DEFAULT_SAMPLE_RATE,
        hop_size: int = DEFAULT_HOP_SIZE,
        timestamp: float = 0.0,
    ) -> "AudioFeatures":
        return cls(
            timestamp=timestamp,
            sample_rate=sample_rate,
            hop_size=hop_size,
            bands=(0.0,) * DEFAULT_BAND_COUNT,
            spectral_centroid=0.0,
            rms_energy=0.0,
            onset_strength=0.0,
            beat_phase=0.0,
            bpm=0.0,
            tempo_confidence=0.0,
        )


def _maximum_filter_1d(values: np.ndarray) -> np.ndarray:
    left = np.concatenate(([values[0]], values[:-1]))
    right = np.concatenate((values[1:], [values[-1]]))
    return np.maximum(np.maximum(left, values), right)


def _normalise_bands(power: np.ndarray, band_masks: tuple[np.ndarray, ...]) -> tuple[float, ...]:
    total = float(np.sum(power)) + 1e-12
    bands = []
    for mask in band_masks:
        if not np.any(mask):
            bands.append(0.0)
            continue
        bands.append(float(np.sum(power[mask]) / total))
    return tuple(bands)


class AudioAnalyzer:
    """Incremental STFT-based audio feature extractor for the live path."""

    def __init__(
        self,
        sample_rate: int = DEFAULT_SAMPLE_RATE,
        hop_size: int = DEFAULT_HOP_SIZE,
        window_size: int = DEFAULT_WINDOW_SIZE,
        band_count: int = DEFAULT_BAND_COUNT,
        min_bpm: float = DEFAULT_MIN_BPM,
        max_bpm: float = DEFAULT_MAX_BPM,
    ) -> None:
        if hop_size <= 0 or window_size <= 0:
            raise ValueError("hop_size and window_size must be positive")
        if hop_size > window_size:
            raise ValueError("hop_size must be <= window_size")
        if band_count != DEFAULT_BAND_COUNT:
            raise ValueError("Phase 2 expects exactly 8 logarithmic bands")

        self.sample_rate = sample_rate
        self.hop_size = hop_size
        self.window_size = window_size
        self.band_count = band_count
        self.min_bpm = min_bpm
        self.max_bpm = max_bpm

        self._window = np.hanning(window_size).astype(np.float32)
        self._sample_window = np.zeros(window_size, dtype=np.float32)
        self._pending = np.empty(0, dtype=np.float32)
        self._frame_index = 0
        self._previous_magnitude = np.zeros(window_size // 2 + 1, dtype=np.float32)

        self._adaptive_window = 12
        self._flux_history: deque[float] = deque(maxlen=max(64, self._adaptive_window * 8))
        self._threshold_history: deque[float] = deque(maxlen=max(64, self._adaptive_window * 8))
        self._time_history: deque[float] = deque(maxlen=max(64, self._adaptive_window * 8))
        self._onset_env_frames = max(3, int(math.ceil((6.0 * sample_rate) / hop_size)))  # 6s window for robust tempo at slow BPM
        self._onset_envelope: deque[float] = deque(maxlen=self._onset_env_frames)
        self._onset_times: deque[float] = deque(maxlen=128)
        self._last_onset_time = -1e9
        self._beat_anchor_time: float | None = None
        self._bpm_estimate = 0.0
        self._tempo_alpha = 0.05
        self._min_inter_onset = 0.05
        # Confidence tracking: rolling window of recent BPM estimates
        # High variance = low confidence; zero estimates = zero confidence
        self._bpm_history: deque[float] = deque(maxlen=40)  # ~5s at 512 hop
        self._tempo_confidence = 0.0

        nyquist = sample_rate / 2.0
        freqs = np.fft.rfftfreq(window_size, d=1.0 / sample_rate)
        band_edges = np.geomspace(20.0, max(21.0, nyquist), band_count + 1)
        band_edges[-1] = nyquist
        self._freqs = freqs
        self._band_edges = tuple(float(edge) for edge in band_edges)
        self._band_masks = tuple(
            (freqs >= band_edges[idx]) & (freqs < band_edges[idx + 1])
            if idx < band_count - 1
            else (freqs >= band_edges[idx]) & (freqs <= band_edges[idx + 1])
            for idx in range(band_count)
        )

    @property
    def band_labels(self) -> tuple[str, ...]:
        return _BAND_LABELS

    def process_samples(self, samples: np.ndarray) -> list[AudioFeatures]:
        """Process arbitrary-size mono audio and emit one feature vector per hop."""
        mono = np.asarray(samples, dtype=np.float32).reshape(-1)
        if mono.size == 0:
            return []

        if self._pending.size == 0:
            self._pending = mono
        else:
            self._pending = np.concatenate((self._pending, mono))

        features: list[AudioFeatures] = []
        while self._pending.size >= self.hop_size:
            hop = self._pending[: self.hop_size]
            self._pending = self._pending[self.hop_size :]
            self._sample_window = np.roll(self._sample_window, -self.hop_size)
            self._sample_window[-self.hop_size :] = hop
            features.append(self._analyze_current_window())
        return features

    def _analyze_current_window(self) -> AudioFeatures:
        self._frame_index += 1
        timestamp = (self._frame_index * self.hop_size) / float(self.sample_rate)

        windowed = self._sample_window * self._window
        magnitude = np.abs(np.fft.rfft(windowed)).astype(np.float32)
        power = magnitude * magnitude
        rms = float(np.sqrt(np.mean(np.square(self._sample_window), dtype=np.float64)))

        magnitude_sum = float(np.sum(magnitude))
        if magnitude_sum > 0.0:
            centroid = float(np.dot(self._freqs, magnitude) / magnitude_sum)
        else:
            centroid = 0.0

        bands = _normalise_bands(power, self._band_masks)

        filtered_previous = _maximum_filter_1d(self._previous_magnitude)
        flux = float(np.maximum(0.0, magnitude - filtered_previous).sum())
        self._previous_magnitude = magnitude

        threshold = self._compute_threshold(flux)
        onset_strength = max(0.0, flux - threshold)
        self._flux_history.append(flux)
        self._threshold_history.append(threshold)
        self._time_history.append(timestamp)
        self._onset_envelope.append(onset_strength)
        self._detect_onset()

        candidate_bpm = self._estimate_bpm()
        if candidate_bpm > 0.0:
            if self._bpm_estimate <= 0.0:
                self._bpm_estimate = candidate_bpm
            else:
                self._bpm_estimate = (
                    (1.0 - self._tempo_alpha) * self._bpm_estimate
                    + self._tempo_alpha * candidate_bpm
                )
            self._bpm_history.append(self._bpm_estimate)

        # Compute tempo confidence: 0 when no estimate, higher when stable
        # Uses coefficient of variation (std/mean) — low CV = high confidence
        if len(self._bpm_history) >= 8 and self._bpm_estimate > 0.0:
            arr = np.asarray(self._bpm_history, dtype=np.float32)
            cv = float(np.std(arr) / (np.mean(arr) + 1e-6))
            # CV < 0.02 (2% variation) = confident; CV > 0.15 = not confident
            raw_conf = 1.0 - min(1.0, cv / 0.15)
            # Blend toward new confidence slowly (0.1 alpha = stable)
            self._tempo_confidence = 0.9 * self._tempo_confidence + 0.1 * raw_conf
        elif self._bpm_estimate <= 0.0:
            self._tempo_confidence *= 0.95  # decay when no estimate

        beat_phase = self._compute_beat_phase(timestamp)

        return AudioFeatures(
            timestamp=timestamp,
            sample_rate=self.sample_rate,
            hop_size=self.hop_size,
            bands=bands,
            spectral_centroid=centroid,
            rms_energy=rms,
            onset_strength=onset_strength,
            beat_phase=beat_phase,
            bpm=float(self._bpm_estimate),
            tempo_confidence=float(self._tempo_confidence),
        )

    def _compute_threshold(self, flux: float) -> float:
        if not self._flux_history:
            return flux
        recent = np.asarray(
            list(self._flux_history)[-self._adaptive_window :] + [flux],
            dtype=np.float32,
        )
        return float(np.mean(recent) + 0.5 * np.std(recent))

    def _detect_onset(self) -> None:
        if len(self._flux_history) < 3:
            return

        flux = list(self._flux_history)
        threshold = list(self._threshold_history)
        times = list(self._time_history)
        idx = len(flux) - 2
        is_peak = flux[idx] > flux[idx - 1] and flux[idx] >= flux[idx + 1]
        is_salient = flux[idx] > threshold[idx]
        onset_time = times[idx]
        respects_gap = (onset_time - self._last_onset_time) >= self._min_inter_onset
        if is_peak and is_salient and respects_gap:
            self._last_onset_time = onset_time
            self._beat_anchor_time = onset_time
            self._onset_times.append(onset_time)

    def _estimate_bpm(self) -> float:
        if len(self._onset_envelope) < 8:
            return 0.0

        envelope = np.asarray(self._onset_envelope, dtype=np.float32)
        envelope = envelope - float(np.mean(envelope))
        envelope = np.maximum(envelope, 0.0)
        if not np.any(envelope > 0.0):
            return 0.0

        autocorr = np.correlate(envelope, envelope, mode="full")[len(envelope) - 1 :]
        min_lag = max(
            1,
            int(math.floor((60.0 * self.sample_rate) / (self.max_bpm * self.hop_size))),
        )
        max_lag = min(
            len(autocorr) - 1,
            int(math.ceil((60.0 * self.sample_rate) / (self.min_bpm * self.hop_size))),
        )
        if max_lag <= min_lag:
            return 0.0

        search = autocorr[min_lag : max_lag + 1]
        if search.size == 0 or float(np.max(search)) <= 0.0:
            return 0.0

        # Find top-3 peaks in the search window to resolve metrical ambiguity.
        # The autocorrelation often peaks at sub-beat lags (double tempo).
        # We prefer the largest lag (lowest BPM candidate) among peaks whose
        # autocorrelation value is at least 70% of the global maximum, then
        # verify the half-tempo candidate doesn't score meaningfully higher.
        global_max = float(np.max(search))
        threshold = 0.70 * global_max

        # Collect all local maxima above threshold
        candidates: list[tuple[float, int]] = []  # (score, lag)
        for i in range(1, len(search) - 1):
            if search[i] >= threshold and search[i] >= search[i-1] and search[i] >= search[i+1]:
                lag = i + min_lag
                candidates.append((float(search[i]), lag))

        if not candidates:
            # Fall back to simple argmax
            peak_lag = int(np.argmax(search)) + min_lag
        else:
            # Sort by lag descending (prefer slower tempo = larger lag)
            candidates.sort(key=lambda x: x[1], reverse=True)
            peak_lag = candidates[0][1]

        return float((60.0 * self.sample_rate) / (peak_lag * self.hop_size))

    def _compute_beat_phase(self, timestamp: float) -> float:
        if self._bpm_estimate <= 0.0:
            return 0.0
        period = 60.0 / self._bpm_estimate
        anchor = self._beat_anchor_time if self._beat_anchor_time is not None else timestamp
        if period <= 0.0:
            return 0.0
        return float(((timestamp - anchor) % period) / period)


def analyze_signal(
    samples: np.ndarray,
    sample_rate: int = DEFAULT_SAMPLE_RATE,
    hop_size: int = DEFAULT_HOP_SIZE,
    window_size: int = DEFAULT_WINDOW_SIZE,
) -> list[AudioFeatures]:
    """Offline convenience helper for tests and validation scripts."""
    analyzer = AudioAnalyzer(
        sample_rate=sample_rate,
        hop_size=hop_size,
        window_size=window_size,
    )
    return analyzer.process_samples(samples)


class AudioFeatureBuffer:
    """Latest-value exchange between audio callback thread and render thread."""

    def __init__(self, initial: AudioFeatures | None = None) -> None:
        self._lock = threading.Lock()
        self._event = threading.Event()
        self._latest = initial or AudioFeatures.silence()

    def update(self, features: AudioFeatures) -> None:
        with self._lock:
            self._latest = features
            self._event.set()

    def latest(self) -> AudioFeatures:
        with self._lock:
            return self._latest

    def wait_for_update(self, timeout: float | None = None) -> bool:
        updated = self._event.wait(timeout=timeout)
        self._event.clear()
        return updated


def list_input_devices() -> list[dict[str, Any]]:
    """Return available audio input devices."""
    try:
        import sounddevice as sd
    except ImportError:
        return []

    devices = []
    for index, device in enumerate(sd.query_devices()):
        channels = int(device.get("max_input_channels", 0) or 0)
        if channels <= 0:
            continue
        devices.append(
            {
                "index": index,
                "name": str(device.get("name", f"device-{index}")),
                "channels": channels,
                "default_samplerate": float(device.get("default_samplerate", 0.0) or 0.0),
            }
        )
    return devices


@dataclass(slots=True)
class NullAudioSource:
    """Fallback when sounddevice is unavailable or capture fails."""

    sample_rate: int = DEFAULT_SAMPLE_RATE
    hop_size: int = DEFAULT_HOP_SIZE

    def start(self, feature_buffer: AudioFeatureBuffer) -> None:
        feature_buffer.update(
            AudioFeatures.silence(sample_rate=self.sample_rate, hop_size=self.hop_size)
        )

    def close(self) -> None:
        return None


@dataclass(slots=True)
class SoundDeviceAudioSource:
    """Real-time audio capture backed by sounddevice callbacks."""

    device: int | None = None
    sample_rate: int = DEFAULT_SAMPLE_RATE
    hop_size: int = DEFAULT_HOP_SIZE
    window_size: int = DEFAULT_WINDOW_SIZE
    min_bpm: float = DEFAULT_MIN_BPM
    max_bpm: float = DEFAULT_MAX_BPM
    _stream: Any = field(init=False, default=None, repr=False)
    _analyzer: AudioAnalyzer = field(init=False, repr=False)

    def __post_init__(self) -> None:
        self._analyzer = AudioAnalyzer(
            sample_rate=self.sample_rate,
            hop_size=self.hop_size,
            window_size=self.window_size,
            min_bpm=self.min_bpm,
            max_bpm=self.max_bpm,
        )

    def start(self, feature_buffer: AudioFeatureBuffer) -> None:
        try:
            import sounddevice as sd
        except ImportError as exc:
            raise RuntimeError("sounddevice is not installed") from exc

        def callback(indata: np.ndarray, frames: int, time_info: Any, status: Any) -> None:
            if status:
                warnings.warn(f"Audio callback status: {status}", RuntimeWarning)
            del frames, time_info
            mono = np.asarray(indata[:, 0], dtype=np.float32)
            for features in self._analyzer.process_samples(mono):
                feature_buffer.update(features)

        self._stream = sd.InputStream(
            channels=1,
            samplerate=self.sample_rate,
            blocksize=self.hop_size,
            dtype="float32",
            callback=callback,
            device=self.device,
        )
        self._stream.start()

    def close(self) -> None:
        if self._stream is None:
            return
        self._stream.stop()
        self._stream.close()
        self._stream = None

