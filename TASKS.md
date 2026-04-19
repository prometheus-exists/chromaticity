# Tasks — Chromaticity

Rolling task list. `--ignore` flags and deferred work tracked here. When a task closes, move to CHANGELOG.md.

## Open

- [ ] Phase 1: Render-probe uniform analyser (see design doc, docs/reference/ADR/ADR-001)
- [ ] Phase 2: Live audio-reactive runtime
- [ ] Phase 3: CMC-principled mapping integration
- [ ] Phase 4: UX layer (shader library, mapping editor, performance mode)
- [ ] Mapping profile JSON schema — not yet specified (ADR-003 to be written when we design it)
- [ ] Beat tracking validation: compare aubio-inferred BPM against human-tapped ground truth on the untagged test track (Fletcher ear-taps his own track). Live performance gets raw audio, no metadata — the pipeline must work from waveform alone.
- [ ] Photosensitive epilepsy safety mode — flicker rate limiting + user opt-in for strobe effects (Phase 2+)
- [ ] Windows audio backend testing (sounddevice behaviour differs from macOS; validate WASAPI/MME/DirectSound paths)
- [ ] macOS audio backend testing (CoreAudio permissions, device hot-swap handling)
- [ ] GPU context loss recovery (long sessions + device switch — live performance requirement)
- [ ] Shader sandboxing — what's the blast radius if a loaded shader is malicious/broken? (ADR required)

## Deferred

- [ ] Linux support — not blocking, add when someone needs it
- [ ] Prediction-error visualiser (from initial design conversation) — needs Witek et al. read + phrase-level refactor
- [ ] Individual CMC calibration layer — research-interesting, not v1
- [ ] Shadertoy marketplace integration — API exists, may be useful later

## Ignore-flag tracking

None yet. When a test gets `--ignore`, add entry here with owner + target fix date.

## Known trade-offs

- AGPL ShaderFlow is studied for architecture but not vendored (we're MIT; can't absorb AGPL code)
- madmom has NC-licensed models — use offline only, never in distribution
- aubio is GPL — we depend on it but don't redistribute it; users install via uv
