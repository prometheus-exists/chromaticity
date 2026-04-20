# ADR-003: Mapping Profile JSON Schema

**Date**: 2026-04-20  
**Status**: Accepted  
**Deciders**: Xavier, Fletcher, Prometheus  
**Context**: Phase 1 render-probe implementation (see phase1-codex-brief.md)

## Context

The render-probe pipeline (ADR-001) produces a characterisation of each shader's visual response to uniform sweeps. This characterisation must be stored in a format that:
- The offline probe (Phase 1) can write
- The live path (Phase 2) can read to make audio→uniform mapping decisions
- The CMC mapping layer (Phase 3) can use to attach perceptual semantics

The schema is an API contract between three separate phases of the pipeline. Getting it wrong now means breaking changes later when live-path code is written.

## Decision

### Schema version: `"1.0"`

Profiles are JSON files stored in `profiles/<shader_id>.json`. The schema is versioned at the top level; breaking changes increment the major version.

### Top-level structure

```json
{
  "schema_version": "1.0",
  "shader_id": "3sySRK",
  "shader_path": "test-shaders/3sySRK.glsl",
  "probe_date": "2026-04-20T19:00:00",
  "probe_config": { ... },
  "itime_sensitivity": { ... },
  "uniforms_detected": ["iTime", "iResolution"],
  "flags": { ... }
}
```

### `probe_config` object

Records the exact parameters used to generate this profile. Required for reproducibility and for detecting when a re-probe is needed.

```json
{
  "resolution": [512, 512],
  "itime_start": 0.0,
  "itime_end": 60.0,
  "itime_step": 1.0,
  "warmup_frames": 0,
  "multi_pass": false,
  "feedback_loop": false
}
```

### `itime_sensitivity` object

Three sub-objects, one per metric dimension. Each contains a raw time series (one value per iTime sample) and a scalar summary.

**Luminance:**
```json
{
  "mean": [0.42, 0.44, ...],
  "std": 0.12,
  "range": [0.31, 0.67],
  "sensitivity_score": 0.0
}
```
- `mean[t]`: mean luminance (0–1) at iTime sample t
- `std`: standard deviation of `mean` across the sweep
- `range`: [min, max] of `mean`
- `sensitivity_score`: placeholder formula `std(mean) / (mean(abs(mean)) + 1e-6)`, normalised post-hoc against full suite

**Colour:**
```json
{
  "mean_L": [...],
  "mean_a": [...],
  "mean_b": [...],
  "std_a": [...],
  "std_b": [...],
  "mean_chroma": [...],
  "colour_velocity": [...],
  "sensitivity_score": 0.0
}
```
- All arrays: one value per iTime sample
- `mean_L/a/b`: CIELAB spatial means (not RGB — see rationale below)
- `std_a/b`: spatial standard deviation of a* and b* channels — captures colour *spread* within a frame, not just the centre
- `mean_chroma`: `mean(sqrt(a²+b²))` — distance from achromatic axis, perceptually meaningful
- `colour_velocity`: `|mean_chroma[t] - mean_chroma[t-1]|` — rate of colour change between consecutive samples. First entry = 0.0
- `sensitivity_score`: `std(mean_chroma) / (mean(mean_chroma) + 1e-6)`

**Motion:**
```json
{
  "ssim_dissimilarity": [...],
  "mean_dissimilarity": 0.0,
  "sensitivity_score": 0.0
}
```
- `ssim_dissimilarity[t]`: `1 - SSIM(frame_t, frame_{t-1})`. First entry = 0.0
- `mean_dissimilarity`: mean of the series (excludes first entry)
- `sensitivity_score`: same as `mean_dissimilarity` (already normalised 0–1 by SSIM definition)

### `uniforms_detected` array

List of uniform names found in the shader source by static analysis. Order: Shadertoy builtins first (iTime, iResolution, iMouse, iChannelN), then custom uniforms alphabetically.

### `flags` object

```json
{
  "multi_pass": false,
  "feedback_loop": false,
  "needs_ichannel0": false,
  "compilation_error": null,
  "warmup_frames_used": 0,
  "sweep_complete": true,
  "possibly_incomplete": false
}
```
- `compilation_error`: null if no error, string error message otherwise. If set, all metric arrays are null.
- `warmup_frames_used`: actual frames rendered per sample during warmup (feedback shaders only)
- `sweep_complete`: false if the 60s watchdog fired before sweep finished
- `possibly_incomplete`: true if autocorrelation heuristic detects the signal was still evolving at sweep end (`std(series[-10:]) / (std(series) + 1e-6) > 0.5`)

## Rationale

### Why CIELAB and not RGB?

The mean of two complementary RGB colours (e.g. red + cyan) is grey. A probe measuring mean RGB colour centroid would report "achromatic" for 7cBSDR, which cycles through the full hue spectrum. CIELAB is perceptually uniform — distances in CIELAB correspond to perceived colour differences. This is required for the CMC mapping layer (Phase 3), which maps audio arousal/valence to perceptual colour dimensions.

### Why SSIM dissimilarity and not optical flow?

Optical flow computes directional motion vectors — more information than we need for profiling, and significantly more expensive. SSIM dissimilarity captures "how much did the image change frame-to-frame" in a perceptually motivated way (it separately accounts for luminance, contrast, and structural differences). This is sufficient for classifying a uniform as "motion-driving" vs "colour-driving" vs "static."

Motion direction may be added in Phase 2+ if the live path needs to map audio panning to visual directionality.

### Why `colour_velocity` in the schema?

The central research hypothesis: visual colour-change *rate* should match emotional tempo (timescales of 2–8 seconds, not beat-level). `colour_velocity` is the direct operationalisation of this — it lets Phase 3 select iTime scaling that produces colour-change rates matching the estimated emotional tempo of a track. Storing it in the profile (rather than computing on-the-fly) makes Phase 3 a lookup operation rather than a recompute.

### Why store raw time series rather than just summaries?

Phase 3 needs the full temporal shape to match emotional velocity curves, not just aggregate statistics. A profile with only `sensitivity_score` would tell you "this shader responds to iTime" but not *how* — linearly? periodically? with a lag? The raw series preserves this. Storage cost is negligible (~60 floats per metric per shader).

### Why 512×512?

Colour distribution and SSIM statistics converge quickly with spatial samples. 512² = 262,144 pixels is more than sufficient for stable colour moments. Validated empirically: run one shader at 512×512 and 1080p, compare profiles. If they diverge significantly, increase. The brief anticipates they won't.

### Why 60s sweep / 1s step as defaults?

60s captures most Shadertoy shader periods (common periods: 1s–30s). 1s step gives 60 samples — enough for temporal shape without excessive render cost. Override with `--itime-end` and `--itime-step` for shaders with known longer periods (e.g. XdycWG's slow sun movement at `cos(iTime*0.02)` = ~314s period, well outside the default window).

## Consequences

- Phase 2 (live path) reads `itime_sensitivity.colour.colour_velocity` and `itime_sensitivity.motion.ssim_dissimilarity` to select iTime update rate
- Phase 3 (CMC mapping) uses `itime_sensitivity.colour.mean_chroma` and `colour_velocity` to match audio arousal velocity to visual colour velocity
- Profile files are committed to the repo under `profiles/` for reproducibility
- Schema changes are versioned; Phase 2+ code must check `schema_version` before reading
- A profile is invalidated (re-probe needed) when: shader source changes, `probe_config` parameters change, or `schema_version` increments
