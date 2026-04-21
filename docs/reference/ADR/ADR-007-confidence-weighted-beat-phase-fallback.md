# ADR-007: Confidence-Weighted Beat_Phase Fallback

**Status**: Accepted  
**Date**: 2026-04-21  
**Authors**: Prometheus, Xavier Butler, Fletcher Hammond  
**Scope**: Phase 2 `UniformMapper`, audio feature routing

---

## Context

The Phase 2 `UniformMapper` routes `beat_phase` (a 0→1 sawtooth per detected beat) to motion-class shader uniforms. This is the correct mapping when tempo detection is reliable.

However, Chromaticity must function across all genres and musical contexts, including:
- **Irregular meter** (polyrhythm, mixed time signatures, e.g. tracks alternating 5/4 and 4/4)
- **Silence and transitions** between tracks
- **Ambient/non-rhythmic material** with no clear pulse
- **Track boundaries** where the detector has not yet stabilised

When `beat_phase` is locked to an unreliable BPM estimate, the visualiser either freezes (no detected beat = no phase advance) or jitters (rapidly shifting BPM estimate = discontinuous phase). Both are perceptually wrong.

## Decision

The mapper applies a **confidence-weighted blend** for `beat_phase`-mapped uniforms:

```
output = confidence × beat_phase + (1 − confidence) × band_0
```

Where:
- `confidence` = `AudioFeatures.tempo_confidence` (0.0 = unstable, 1.0 = stable)
- `beat_phase` = 0→1 sawtooth locked to detected BPM
- `band_0` = sub-bass energy (0.0–1.0, instantaneous, no detection required)

`tempo_confidence` is computed as `1 − min(1, CV / 0.15)` where CV is the coefficient of variation of BPM estimates over the last ~5 seconds (40 frames at 512 hop / 44.1kHz). It is smoothed with α=0.1 to avoid rapid flicker.

## Rationale

**Why sub-bass as the fallback?**  
Sub-bass energy (20–80 Hz, `band_0`) is the most reliable perceptual anchor for low-frequency rhythmic events — kick drums, bass hits, low synth pulses. In the absence of a locked tempo grid, sub-bass energy tracks the physical pulse of the music without requiring BPM detection. The visualiser remains reactive and musically coherent even when the tempo tracker is uncertain.

**Why a blend rather than a hard switch?**  
A hard switch (confidence > threshold → beat_phase; else → band_0) would produce a discontinuous jump when the threshold is crossed. The blend provides smooth perceptual continuity as the detector gains or loses confidence.

**Why not use onset_strength as the fallback?**  
Onset strength is a transient signal — it fires on events rather than tracking a continuous state. band_0 provides a sustained low-frequency energy level that better approximates the "felt weight" of the music in the absence of tempo lock.

## Perceptual implications (Fletcher Hammond, 2026-04-21)

This is a Phase 2→3 bridge decision. In Phase 3, the CMC-principled mapping will include explicit handling of confidence-dependent routing. This ADR documents the Phase 2 interim approach so it can be reviewed and extended rather than inadvertently preserved.

Known limitation: the blend produces a value that is neither a true beat phase (0→1 sawtooth) nor a pure energy signal. Shaders that depend on the phase shape of `beat_phase` (e.g. using it to drive a sinusoidal oscillation) will behave differently when the fallback engages. This is acceptable for Phase 2 — Phase 3 should consider splitting the blend into separate `beat_phase_locked` and `bass_energy` uniforms and letting the mapping layer decide how to combine them.

## Consequences

- ✅ Visualiser remains reactive on irregular-meter and ambient material
- ✅ No freezing or jittering on tempo detection failure
- ✅ Smooth perceptual transition between tempo-locked and energy-driven modes
- ⚠️ `beat_phase` uniform no longer guarantees sawtooth shape when confidence < 1.0
- ⚠️ Phase 3 should split into separate uniforms for clean CMC routing

## Alternatives considered

1. **Hard freeze on beat_phase when no BPM detected**: perceptually bad — visualiser goes static
2. **Continuous beat_phase advance at last known BPM**: drifts out of sync on tempo changes
3. **onset_strength as fallback**: transient rather than sustained — inappropriate for primary pulse
4. **Hard switch at confidence threshold**: discontinuous visual jump
