# Changelog

All notable changes to Chromaticity will be documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

## [Unreleased]

### Planned
- Phase 2: Live audio-reactive runtime (custom onset/beat detector, <5ms live path)
- Phase 3: CMC-principled mapping integration (Palmer 2013 emotion-mediated colour)
- Phase 4: UX (shader library, mapping editor, setlist-prep mode, performance mode)

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
