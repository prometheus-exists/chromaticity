# ADR-003: MIT-permissive licensing — no GPL/AGPL/NC dependencies

**Date**: 2026-04-19
**Status**: Accepted
**Deciders**: Xavier, Fletcher, Prometheus

## Context

Chromaticity started with MIT license but the dependency graph drew in GPL (aubio), AGPL (ShaderFlow as reference), and CC-BY-NC-SA (madmom models) components. MIT is legally incompatible with GPL/AGPL linking: the combined work inherits the strong copyleft license.

Further, Xavier and Fletcher want the project to:
1. Be usable at paid gigs (commercial performances)
2. Potentially be sold as a product in the future
3. Not impose restrictions on derivative works

CC-BY-NC (madmom models) explicitly forbids commercial use. GPL/AGPL forces the entire combined work to be GPL/AGPL on distribution. AGPL additionally forces source disclosure to any network user — problematic if Chromaticity ever ships a hosted/streaming variant.

## Decision

**License: MIT.** All dependencies must be MIT, BSD, ISC, Apache 2.0, or equivalent permissive licenses. No GPL, no AGPL, no LGPL (dynamic linking still has copyleft implications on macOS/Windows). No NC-licensed models or data.

Specifically:
- **Audio analysis**: librosa (ISC) for offline analysis. Custom real-time onset/beat detection using numpy FFT + spectral flux + autocorrelation. No aubio. No essentia. No BTrack. No madmom models.
- **Rendering**: moderngl (BSD) directly. No ShaderFlow as a dependency (it's AGPL — we study its architecture only).
- **Beat tracking**: implement SuperFlux-style onset detection from scratch (Böck & Widmer 2013 is published; algorithm is not patented). ~200-300 lines of Python.

## Rationale

1. **Maximum commercial flexibility**: MIT allows any use, including paid gigs, selling copies, embedding in proprietary products, without obligations.
2. **No surprises for contributors**: contributors' work is also MIT; they know exactly what they're agreeing to.
3. **Future optionality**: if Chromaticity becomes a commercial product, service, or open-source distribution, MIT supports all three.
4. **Forces discipline**: permissive licensing = we write more ourselves. No "just import GPL X and move on" shortcut. Cleaner codebase.

## Consequences

### Immediate
- Remove `aubio` from `pyproject.toml` dependencies
- Keep `moderngl` (already BSD)
- Keep `sounddevice` (MIT, verified)
- Keep `numpy` (BSD)
- Remove any ShaderFlow code references (reference repo docs only describe architecture; no code copied)

### Engineering cost
- **Real-time beat detection**: must implement. Spectral flux onset detection + autocorrelation tempo estimation. Target: <1ms per frame. Well-documented algorithm (SuperFlux, Böck et al.), not patented, routinely reimplemented.
- **Onset detection**: similar. Energy-based + spectral-flux-based detectors are straightforward.
- **Validation**: without madmom/aubio as reference ground truth, we need another baseline. Option: use librosa (ISC) offline to generate ground-truth beat grids for our test tracks; use those to validate our real-time implementation's accuracy.

### Benefits
- **Clean license story**: MIT in, MIT out. No "but you need to also comply with X" footnotes.
- **Transparent audio pipeline**: users can inspect and modify our beat detection. aubio/madmom are black boxes to most users.
- **Pedagogical value**: well-commented beat detection implementation is useful for perception-science collaborators who want to understand what "onset" means concretely.

## Alternatives considered

### Option A: License Chromaticity as AGPL-3.0
Rejected. Forces all users and commercial deployments to comply with AGPL's network-disclosure clause. Incompatible with "be usable at paid gigs, potentially sell copies."

### Option B: Hybrid — MIT core, GPL/AGPL as optional subprocesses
Rejected. Fragile: legal ambiguity around "mere aggregation" vs linking depends on how we invoke subprocesses. Defensible but creates ongoing legal complexity. Not worth the risk for the engineering savings.

### Option C (chosen): MIT-permissive, swap all copyleft deps
Chosen. Clean, unambiguous, imposes no constraints on future use. Engineering cost is real but bounded (~1 week of work to implement beat detection from scratch).

## Implementation checklist

- [ ] Remove `aubio` from `pyproject.toml`
- [ ] Add `librosa` as offline-analysis dependency
- [ ] Implement `chromaticity.audio.onset_detector` (SuperFlux-style)
- [ ] Implement `chromaticity.audio.tempo_tracker` (autocorrelation)
- [ ] Validate against librosa beat detection on `brotherdurry-constancy.mp3`
- [ ] Update references/README.md to note which repos we can only study (AGPL/GPL) vs which we can integrate (permissive)
- [ ] Update LICENSE file to confirm MIT with explicit note about permissive-only dependencies
