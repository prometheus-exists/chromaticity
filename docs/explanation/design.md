# Chromaticity — Design Document

**Version**: 0.1 (scaffold)  
**Date**: 2026-04-19  
**Authors**: Xavier, Fletcher Hammond, Prometheus

## Core Design Decisions

### What we're building
A live music visualiser that makes arbitrary Shadertoy-compatible GLSL shaders audio-reactive using perceptually principled parameter mappings.

### What we're not building
- A shader marketplace (anti-Synesthesia: no paywall, no locked presets)
- An AI-native visualiser (AI is used to build it, not as a runtime dependency)
- A full VJ suite

### Primary use case
Live music performance across genres. Stability > features. A crash on stage is unacceptable.

DnB is the development reference genre (Fletcher's domain), but all design decisions should be genre-agnostic. High-tempo considerations (e.g. half-time metric tracking at 170+ BPM) are implemented as adaptive behaviour based on detected tempo, not genre-specific hard-coding.

### The key insight
Most Shadertoy shaders are visually stunning but not audio-reactive. The barrier isn't GLSL capability — it's that wiring up audio reactivity manually requires knowing both audio DSP and shader programming. We eliminate that barrier with render-probe analysis + principled defaults.

### Rendering stack
- **moderngl** (Python OpenGL bindings) — thin, fast, full GLSL control
- **Shadertoy GLSL dialect** as the target — largest community, best content
- Standard uniforms: `iTime`, `iResolution`, `iAudioData` (Shadertoy-compatible)
- **Platform: macOS + Windows co-primary**. Every feature works on both or doesn't ship. CI tests both.

### Audio pipeline
- `sounddevice` (MIT) — audio capture
- `numpy` FFT — spectral analysis
- **Custom real-time onset detection** (SuperFlux-style, Böck et al. 2013) — spectral flux with adaptive thresholding
- **Custom real-time tempo tracking** — autocorrelation over onset history
- `librosa` (ISC) — **offline analysis only** (test suite validation, not the live path)
- Target: <1ms from capture to feature vector
- See ADR-003 for why we implement these ourselves (MIT-permissive dependency policy)

### Uniform inference: render-probe
See ADR-001. Sweep → observe → profile → cache. No LLM in critical path.

### CMC mappings (perceptual defaults)
Based on cross-modal correspondence literature:
| Audio feature | Visual parameter type | Basis |
|---|---|---|
| Energy / RMS | Brightness / luminance | Universal CMC |
| Spectral centroid | Colour lightness | Pitch-brightness correspondence |
| Tempo / BPM | Motion speed (adaptive: half-time at 160+ BPM) | Temporal correspondence |
| Spectral flux | Spatial complexity / texture | Timbre-texture correspondence |
| Beat onset | Scale / pulse events | Rhythmic entrainment |
| Bassline energy (sub-80Hz) | Low-frequency visual weight | Frequency-size correspondence |
| Arousal (energy + tempo) + Valence (mode/harmony) | Colour palette | Palmer et al. 2013 — emotion mediates colour |

### Colour control model
Colour is the most individually variable CMC. Three-tier control:
1. **Automatic** — emotion-mediated default. Extract arousal (energy + tempo) and valence (harmonic brightness/mode) → map to colour palette. High arousal = warm/saturated; low arousal = cool/desaturated.
2. **Suggested palettes** — curated named presets (warm/energetic, cool/atmospheric, monochrome, neon, etc.). System animates within the palette bounds; user picks the palette.
3. **Manual override** — user selects base colours; system handles animation, saturation modulation, brightness shifts within that palette.

Automatic mode runs by default. Manual override always accessible. This respects the high individual variation in colour-music associations documented in the CMC literature.

These are defaults. Users can adjust per-shader after render-probe analysis.

### Phase plan
- **Phase 0**: Scaffold (this doc, ADRs, standards, repo)
- **Phase 1**: Render-probe uniform analyser (headless, no audio)
- **Phase 2**: Live audio-reactive runtime (no intelligence, raw FFT → uniforms)
- **Phase 3**: CMC integration (render-probe profiles + perceptual mapping)
- **Phase 4**: UX (shader library, mapping editor, performance mode)

### Collaboration
- Repo: `prometheus-exists/chromaticity` (public, MIT)
- Fletcher contributes via GitHub PRs and issues (Windows, no local lab access)
- Design discussions in #lab Discord, decisions recorded in ADRs
- Xavier + Prometheus build; Fletcher reviews, tests, provides perceptual expertise

### Competitive observations (from active Synesthesia use)
- Colour scheme flexibility is poor — presets are rigid, insufficient per-shader control
- No good reason for this limitation architecturally; it's a product decision that frustrates users
- Chromaticity should make colour fully configurable at every level (palette, per-parameter, per-shader)

### Open questions
- Shader uniform range metadata: rely on Shadertoy `rangeDef` annotations? Or probe-inferred ranges?
- Output: direct fullscreen window, or Syphon/Spout/NDI for routing into other tools?
- Individual CMC calibration: v1 feature? (Fletcher's Idea 2 from initial discussion)
