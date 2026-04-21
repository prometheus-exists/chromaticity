# Changelog

All notable changes to Chromaticity will be documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

## [Unreleased]

### Planned
- Phase 3: CMC-principled mapping integration (Palmer 2013 emotion-mediated colour)
- Phase 4: UX (shader library, mapping editor, setlist-prep mode, performance mode)

---

## [0.3.0] — 2026-04-21

### Added
- **Phase 2: Live audio-reactive runtime** — end-to-end audio capture → feature extraction → uniform injection → live render loop
- **`AudioAnalyzer`** (`chromaticity/audio.py`) — custom SuperFlux-style onset detector (spectral flux + adaptive threshold), autocorrelation-based tempo tracker, 8-band STFT energy extraction, spectral centroid, RMS energy. ~350 LOC, no GPL dependencies.
- **`AudioFeatures` dataclass** — per-frame feature snapshot: bands (8), spectral_centroid, rms_energy, onset_strength, beat_phase, bpm, tempo_confidence
- **`tempo_confidence`** — rolling coefficient-of-variation over BPM history; 0.0 = unstable/unknown, 1.0 = stable. Confidence-weighted beat_phase blend: when low, beat_phase falls back to sub_bass (band_0) energy for genre-agnostic graceful degradation
- **`AudioFeatureBuffer`** — thread-safe latest-value exchange between audio callback thread and render thread
- **`SoundDeviceAudioSource`** — real-time audio capture via sounddevice callbacks (MIT)
- **`NullAudioSource`** — silent fallback when no audio device available
- **`UniformMapper`** (`chromaticity/mapper.py`) — maps AudioFeatures → shader uniform values. Frequency-split heuristic defaults (sub_bass→band_0, presence/air→band_6, mid→onset_strength, brightness→rms). Supports JSON mapping file override. Smoothing parameter.
- **`HeadlessBackend`** + **`PygletBackend`** (`chromaticity/live.py`) — offscreen and windowed render backends
- **`run_live()`** — live render loop; <5ms audio-to-uniform path confirmed
- **CLI `live` subcommand** — `python -m chromaticity live <shader.glsl> [--mapping <json>] [--device <idx>] [--width] [--height] [--fps] [--fullscreen] [--min-bpm] [--max-bpm] [--genre {dnb,house,techno,ambient,auto}]`
- **CLI `devices` subcommand** — lists available audio input devices as JSON
- **Genre presets** — `--genre dnb` (min_bpm=80), `house` (min_bpm=100), `techno` (min_bpm=120), `ambient` (min_bpm=40), `auto` (default 60–200)
- **Phase 2 test suite** — `test_click_train_tempo_detection`, `test_run_live_headless_smoke`, `test_default_mapping_heuristics`, `test_custom_mapping_json_round_trip`

### Fixed
- **Onset envelope window**: extended from 2s → 6s at 512 hop for stable BPM detection at slow tempos (<80 BPM)
- **Metrical ambiguity**: prefer-lower-tempo peak selection in autocorrelation to resolve half/double-time ambiguity
- **glsl_parser.py SHADERTOY_BUILTINS**: added `iTimeDelta`, `iFrame`, `iFrameRate`, `iDate`, `iSampleRate`, `iChannelTime`, `iChannelResolution` — previously missing builtins caused incorrect audio mappings on shaders declaring these uniforms
- **HeadlessBackend double-FBO**: removed duplicate framebuffer creation (resource leak)
- **probe.py `datetime.utcnow()`**: replaced deprecated call with `datetime.now(datetime.UTC)`

### Known limitations
- **Irregular meter / mixed time signatures** (e.g. tracks with polyrhythm or tempo changes): autocorrelation-based detector produces musically plausible but metrically ambiguous output. Handled gracefully by tempo_confidence fallback; not a bug.
- **Windows audio backend**: WASAPI/MME/DirectSound not yet validated. macOS CoreAudio validated.
- **Photosensitive safety mode**: STANDARDS.md specifies a 3Hz flicker-rate cap for Phase 2+. Not yet implemented. Planned for Phase 3.
- **vec3/vec4 uniform mapping**: mapper returns `dict[str, float]` only; vector uniforms receive broadcast scalar. Phase 3 will extend mapper for vector-valued output required by CMC colour pipeline.
- **Per-uniform render-probe profiles**: Phase 1 profiles record iTime sensitivity only, not per-uniform visual signatures. Phase 3 classification uses Option (c): itime_sensitivity for overall shader characterisation + name heuristics for per-uniform mapping.

---

## [0.2.1] — 2026-04-20

### Fixed
- **C1**: Error path in `probe.py` crashed on `min([])` when `render_frames` returned empty list — now short-circuits to valid empty profile
- **C2**: `save_profile` used default `allow_nan=True` — switched to `allow_nan=False` (RFC 7159 compliance); NaN in output now raises immediately rather than writing corrupt JSON
- **H1**: `compute_cielab_stats` passed unclamped float32 renderbuffer to `rgb2lab` — added `np.clip([0,1])` + `nan_to_num` guard; HDR and divide-by-zero shaders now produce valid metrics instead of NaN propagation
- **H2**: `motion.sensitivity_score` was set equal to `mean_dissimilarity` — now uses `sensitivity_score()` formula for consistency with luminance/colour dimensions
- **M2**: `test_compilation_gate` lacked `importorskip("moderngl")` guard and weak assertions — now requires moderngl, verifies valid JSON written, verifies empty metrics on error path
- **GL version**: Bumped wrapper from `#version 330` to `#version 410` (matches available GL 4.1 context; required by some shaders using modern GLSL features)
- **7cBSDR desktop GL compat**: Shader used uninitialised variables (`float i,t,v,l` + `O*=i`) which WebGL zero-initialises but desktop GL leaves undefined — added explicit `i=0.,t=0.,v=0.,l=0.` and `O=vec4(0.0)` initialisation
- **iChannel0-3 stub textures**: Texture-sampling shaders (`NddSWs`, `sc2XDR`, `XtK3W3`) failed to compile due to undeclared `iChannel0` identifier — renderer now declares `sampler2D iChannel0-3` uniforms and binds 1×1 mid-grey stub textures

### Removed
- **XdycWG**: Retired from test suite — CC BY-NC-SA licence (non-commercial only), HLSL non-standard functions (`saturate`, `acesToneMapping`), multi-pass Image-only shader with no standalone render path

### Changed
- `compute_luminance` and `compute_cielab_stats` now share `_sanitise()` helper for consistent NaN/Inf handling across all metrics

---

## [0.2.0] — 2026-04-20

### Added
- **Phase 1: Render-probe uniform analyser** (`chromaticity/probe.py`) — CLI + orchestrator
- Profile JSON schema v1.0 (`chromaticity/profile.py`, ADR-003) — CIELAB colour distribution, SSIM motion, `colour_velocity` for emotional velocity hypothesis
- GLSL static parser (`chromaticity/glsl_parser.py`) — uniform extraction, ichannel0 detection, feedback loop detection
- Frame metrics (`chromaticity/metrics.py`) — CIELAB via skimage, SSIM dissimilarity, luminance, sensitivity scoring
- Offscreen moderngl renderer (`chromaticity/renderer.py`) — timeout watchdog, Shadertoy dialect wrapping, float32 FBO
- Phase 1 test suite (`tests/test_probe.py`) — schema validation, negative case noise-floor calibration, compilation gate, single-pass responsiveness
- ADR-003: Mapping profile JSON schema — data contract between render-probe (Phase 1) and live runtime (Phase 2+)
- Test shader suite (8 shaders): `3sySRK`, `7cBSDR`, `Dsf3WH`, `sc2XDR`, `NddSWs`, `XdycWG`, `XtK3W3`, `negative_test` — covering stateless, multi-pass, feedback loop, and static negative case
- `scikit-image>=0.22` dependency (MIT) for CIELAB conversion and SSIM

---

## [0.1.0] — 2026-04-19

### Added
- Scaffold: README, `docs/STANDARDS.md`, CHANGELOG, pyproject.toml, LICENSE (MIT)
- ADR-001: Render-probe for uniform semantic inference
- ADR-002: Pre-process / live runtime split architecture
- ADR-004 (formerly ADR-003 draft): MIT-permissive licensing — aubio (GPL) removed; custom beat detection required
- ADR-005: Shader security & photosensitivity model — three-layer containment, WCAG 2.3 compliant
- ADR-006: Render-probe three-stage inference pipeline
- Tutorial: `docs/tutorials/glsl-for-perception-scientists.md`
- Reference: `docs/reference/vocabulary.md` — shared glossary
- How-to: `docs/how-to/non-code-contribution.md`
- Design document (`docs/explanation/design.md`) with CMC mapping table + phase plan
- Academic prior-art review (Hermes) covering CMC, temporal binding, groove, embodied cognition
- `.gitattributes`, `.pre-commit-config.yaml`, GitHub Actions CI (macOS + Windows, Python 3.11/3.12)
- Issue templates + PR template
- CONTRIBUTING.md, TASKS.md

### Changed
- Platform targets: macOS + Windows co-primary
- Colour control: three-tier (auto/suggested/manual)
- Scope: explicitly genre-agnostic
- Dependencies: aubio → librosa + custom real-time implementation
