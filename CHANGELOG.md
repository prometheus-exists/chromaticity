# Changelog

All notable changes to Chromaticity will be documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

## [Unreleased]

### Added
- Scaffold: README, STANDARDS.md (now at `docs/STANDARDS.md`), CHANGELOG, pyproject.toml
- ADR-001: Render-probe for uniform semantic inference
- ADR-002: Pre-process / live runtime split architecture
- ADR-003: MIT-permissive licensing — no GPL/AGPL/NC dependencies. Aubio removed; custom beat detection required.
- ADR-004: Mapping profile JSON schema (v0.1.0) — data contract between render-probe and live runtime, Fletcher-editable
- ADR-005: Shader security & photosensitivity model — three-layer containment (subprocess isolation + live budgets + safety-by-default), WCAG 2.3 compliant
- ADR-006: Render-probe three-stage inference pipeline — name heuristic → source analysis → render-probe (with explicit timeboxes)
- Tutorial: `docs/tutorials/glsl-for-perception-scientists.md` — 10-minute crash course for non-shader-devs
- Reference: `docs/reference/vocabulary.md` — shared glossary across perception, GLSL, and music
- How-to: `docs/how-to/non-code-contribution.md` — contribution paths that don't require Python
- Design document (`docs/explanation/design.md`) with CMC mapping table + phase plan
- References directory with prior-art repos tiered by relevance
- Academic prior-art review (Hermes, 2026-04-19) covering CMC, temporal binding, groove, embodied cognition, chromesthesia
- `.gitattributes`: enforce LF line endings across platforms
- LICENSE (MIT)
- CONTRIBUTING.md with philosophy + standards + live-performance safety rules
- TASKS.md for tracking open work + known trade-offs
- Diátaxis documentation structure (`docs/{tutorials,how-to,reference,explanation}/`)
- `.pre-commit-config.yaml` for local dev (ruff, black, standard hooks)
- GitHub Actions CI: macOS + Windows, Python 3.11 + 3.12 matrix
- Issue templates (bug report, feature request) + PR template
- Photosensitive epilepsy safety notice in README + STANDARDS accessibility section

### Changed
- STANDARDS.md moved from project root to `docs/STANDARDS.md` (Lab Workflow convention)
- Platform targets elevated: macOS + Windows are **co-primary**, not primary + supported
- Colour control model: three-tier (auto/suggested/manual) — addresses CMC individual variation
- Scope: explicitly genre-agnostic (high-tempo handling is adaptive, not DnB-specific)
- **Dependencies swapped for licensing**: aubio (GPL) removed; librosa (ISC) for offline analysis; real-time onset/beat detection to be implemented in-house (SuperFlux-style, ADR-003)

### Planned
- Phase 1: Render-probe uniform analyser
- Phase 2: Live audio-reactive runtime
- Phase 3: CMC-principled mapping integration
- Phase 4: UX (shader library, mapping editor, performance mode)
