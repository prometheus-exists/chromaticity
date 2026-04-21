# Tasks — Chromaticity

Rolling task list. `--ignore` flags and deferred work tracked here. When a task closes, move to CHANGELOG.md.

## Open

- [x] **Implement real-time onset detector** ✅ 2026-04-21 — SuperFlux-style spectral flux + adaptive threshold, ~200 LOC, `chromaticity/audio.py`
- [x] **Implement real-time tempo tracker** ✅ 2026-04-21 — autocorrelation on 6s onset envelope, prefer-lower-tempo peak selection, `chromaticity/audio.py`
- [x] **Phase 2: Live audio-reactive runtime** ✅ 2026-04-21 — v0.3.0. See CHANGELOG.
- [x] Mapping profile JSON schema — ADR-003 written 2026-04-20, schema v1.0 locked
- [x] Phase 1: Render-probe uniform analyser ✅ 2026-04-20 — CLI + profile schema v1.0, 7-shader suite profiled, noise floor calibrated, all Hermes review findings fixed (v0.2.1)
- [ ] **Phase 3: CMC-principled mapping integration** — spec at `docs/phase3-spec-draft.md`. Pending: Phase 2 MUST fixes, Palmer 2013 read, Hermes Phase 3 design review.
- [ ] Phase 4: UX layer (shader library, mapping editor, performance mode)
- [ ] Validate custom beat detection against librosa baseline on brotherdurry-constancy.mp3 (ADR-003 deliverable, still open)
- [ ] **Photosensitive epilepsy safety mode** — flicker rate limiting, 3Hz cap by default, user opt-in for strobe effects. COMMITTED in STANDARDS.md for Phase 2+. **Safety regression — must ship before any public-facing release.**
- [ ] Windows audio backend testing (sounddevice behaviour differs from macOS; validate WASAPI/MME/DirectSound paths)
- [ ] macOS audio backend testing (CoreAudio permissions, device hot-swap handling)
- [ ] GPU context loss recovery (long sessions + device switch — live performance requirement)
- [ ] Shader sandboxing — what's the blast radius if a loaded shader is malicious/broken? (ADR required)
- [ ] Phase 3 evaluation instrument implementation — web form or CLI tool for 8-item Likert rating (see `docs/phase3-spec-draft.md ## Phase 3 Evaluation Instrument`)

## Known Limitations (Phase 2)

- **Irregular meter / mixed time signatures**: autocorrelation tempo detector produces musically plausible but metrically ambiguous output on tracks with polyrhythm, tempo changes, or mixed meter (e.g. 5/4 + 4/4). Handled gracefully via `tempo_confidence` fallback to sub-bass energy. Not a bug — document in user-facing notes.
- **Onset detector 1-hop latency**: onset events are confirmed one hop (512 samples ≈ 11.6ms at 44.1kHz) after they occur, because peak-picking requires the subsequent frame to confirm a local maximum. `onset_strength` in `AudioFeatures` reflects the current hop's flux value; the beat-anchor reset is delayed by one hop. Acceptable for visual sync; document if sub-10ms onset accuracy is ever required.
- **Windows audio backend**: not validated. macOS CoreAudio validated.
- **Photosensitive safety mode**: not yet implemented (see above).
- **vec3/vec4 uniform mapping**: `map()` returns `dict[str, float]` only. Vector colour uniforms receive broadcast scalar. Phase 3 must extend mapper for vector-valued output.
- **Per-uniform render-probe profiles**: Phase 1 profiles are iTime-only. Phase 3 uses Option (c): overall shader characterisation from itime_sensitivity + name heuristics per uniform. Full per-uniform profiling deferred.

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
