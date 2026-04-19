# Tasks — Chromaticity

Rolling task list. `--ignore` flags and deferred work tracked here. When a task closes, move to CHANGELOG.md.

## Open

- [ ] **Implement real-time onset detector** (SuperFlux-style, ~200-300 LOC) — prerequisite for Phase 2, clean-room implementation per ADR-003
- [ ] **Implement real-time tempo tracker** (autocorrelation on onset history) — prerequisite for Phase 2
- [ ] Validate custom beat detection against librosa baseline on brotherdurry-constancy.mp3
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
- [ ] **"GLSL for Perception Scientists" blog post** — Fletcher-led, publishable on a lab blog / personal site. High value for an underexplored intersection. Source the 1-pager version from Hermes's F3 finding; expand with visual examples. Xavier flagged this 2026-04-19.

## Product direction

- **End-game likely paid product** (Fletcher raised, Xavier reaffirmed 2026-04-19). ADR-003 licensing decision (MIT + permissive deps) keeps this option open.
- **Live performance is non-negotiable**: Fletcher confirmed zero-buffer reactivity requirement (2026-04-19). Eliminates any dependency with >5ms latency in the critical path. Reinforces ADR-002 (preprocess/live split).

## Ignore-flag tracking

None yet. When a test gets `--ignore`, add entry here with owner + target fix date.

## Known trade-offs

- **Licensing**: MIT-permissive only. See ADR-003. No GPL/AGPL/NC deps.
- AGPL ShaderFlow is studied for architecture only — no code absorbed, no dependency
- madmom models are NC-licensed — never used, not even for offline analysis
- aubio is GPL — removed from dependencies; we implement onset/beat detection ourselves (ADR-003)
- librosa (ISC) replaces aubio for offline analysis; real-time path is custom (SuperFlux-style)
