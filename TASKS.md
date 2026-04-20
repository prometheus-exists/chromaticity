# Tasks — Chromaticity

Rolling task list. `--ignore` flags and deferred work tracked here. When a task closes, move to CHANGELOG.md.

## Open

- [ ] **Implement real-time onset detector** (SuperFlux-style, ~200-300 LOC) — prerequisite for Phase 2, clean-room implementation per ADR-003
- [ ] **Implement real-time tempo tracker** (autocorrelation on onset history) — prerequisite for Phase 2
- [ ] Validate custom beat detection against librosa baseline on brotherdurry-constancy.mp3
- [x] Phase 1: Render-probe uniform analyser ✅ 2026-04-20 — CLI + profile schema v1.0, 7-shader suite profiled, noise floor calibrated, all Hermes review findings fixed (v0.2.1)
- [ ] Phase 2: Live audio-reactive runtime
- [ ] Phase 3: CMC-principled mapping integration
- [ ] Phase 4: UX layer (shader library, mapping editor, performance mode)
- [x] Mapping profile JSON schema — ADR-003 written 2026-04-20, schema v1.0 locked
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

## Phase 1 findings (inform Phase 2 design)

- **Three shader archetypes identified** (2026-04-20): colour-dominated (XtK3W3, colour score 1.20), motion-dominated (7cBSDR, dissim 0.975), balanced (3sySRK, both mid-range). Natural taxonomy for curation layer.
- **Texture-dependent shaders (NddSWs, sc2XDR)**: all metrics zero with stub texture — need real texture pipeline, flag as Phase 4 scope.
- **Dsf3WH is near-monochrome**: colour score ~0, all variation is luminance-based. Suitable for motion-only reactive mapping only.
- **Colour velocity ≠ emotional velocity** (Fletcher Hammond 2026-04-20): a cycling palette is high velocity but periodic — the emotional register rotates, it doesn’t climb. Proxy metric needs revision before Exp 4. Candidate: derivative of perceptual surprise (deviation from predicted pattern) rather than raw chroma delta.
- **Per-shader mapping is mandatory** (confirmed): 3sySRK colour sensitivity ~10× higher than 7cBSDR. Universal mapping would overdrive one or underwhelm the other.
- **Irregular colour velocity in 7cBSDR** (spikes t=2s, t=7s, near-zero t=8s): emergent from depth-time interference in the raymarcher. May create natural dialogue with music rhythm — or fight it. Open question for Phase 2 testing.
- **Feedback shaders**: probe infrastructure ready (ping-pong FBO, warmup frames), but no feedback shader profiled yet. Path-dependent profile expected — feedback shader state history affects every frame. Phase 2 must treat these differently.
- **Both auto beat-sync and manual override required** in Phase 2 mapping layer (Xavier + Fletcher 2026-04-20). Two modes: locked (follows detected beats) and free (user drives iTime directly).

## Design ideas (not yet scoped, not yet architectural decisions)

- **Genre-parameterised setlist mode** (Xavier 2026-04-20): the slow layer's time constant for colour palette drift should be genre-specific (8-15s for DnB, 30-60s for ambient/classical — see exploration `2026-04-20-two-layer-matched-filter.md`). A setlist-prep mode where DJs/VJs can tag per-track genre metadata before a set would let Chromaticity auto-configure the emotional bandwidth parameters for each track. Default: plug-and-play with reasonable universal defaults. Expert mode: manual override with pre-set genre profiles or custom time constants. Don't architect this now — note it for Phase 4 UX discussion.

---

## Product direction

- **End-game likely paid product** (Fletcher raised, Xavier reaffirmed 2026-04-19). ADR-003 licensing decision (MIT + permissive deps) keeps this option open.
- **Live performance is non-negotiable**: Fletcher confirmed zero-buffer reactivity requirement (2026-04-19). Eliminates any dependency with >5ms latency in the critical path. Reinforces ADR-002 (preprocess/live split).
- **Accessibility as a feature, not just a constraint** (Fletcher 2026-04-19): photosensitivity accommodation should be leaned into as a differentiator. Most visualiser software is actively hostile to photosensitive users; Chromaticity can be the first that explicitly supports them. Potential marketing positioning + potential future research collaboration angle (visual perception + accessibility = publishable). Reinforces ADR-005 safety-by-default design.

## Ignore-flag tracking

None yet. When a test gets `--ignore`, add entry here with owner + target fix date.

## Known trade-offs

- **Licensing**: MIT-permissive only. See ADR-003. No GPL/AGPL/NC deps.
- AGPL ShaderFlow is studied for architecture only — no code absorbed, no dependency
- madmom models are NC-licensed — never used, not even for offline analysis
- aubio is GPL — removed from dependencies; we implement onset/beat detection ourselves (ADR-003)
- librosa (ISC) replaces aubio for offline analysis; real-time path is custom (SuperFlux-style)
