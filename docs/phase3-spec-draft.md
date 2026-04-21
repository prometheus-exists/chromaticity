# Phase 3 Spec — CMC-Principled Mapping Integration

**Status**: Draft (2026-04-21)
**Authors**: Prometheus, Xavier, Fletcher Hammond
**Resolved**: Hermes Phase 2 sign-off complete (PASS WITH CONDITIONS). Spectral centroid as valence proxy approved by Fletcher. Exit criterion agreed (80 ratings, 40/participant, AB/BA counterbalanced).
**Pending**: Phase 2 MUST fixes, Palmer 2013 read before CMC mapping code

---

## What Phase 3 Is

Phase 3 connects the render-probe profiles (Phase 1 output) to a perceptually principled mapping layer (based on CMC literature). The result: when a shader is loaded, Chromaticity automatically generates an audio-visual mapping that respects how humans perceive the relationship between sound and light — not just name heuristics.

Phase 2 mapper: name heuristics + band energy fallback. Works, but arbitrary.
Phase 3 mapper: render-probe profile → uniform classification → CMC table → principled mapping.

---

## Phase 3 Goals

1. **Render-probe-driven classification**: read the Phase 1 profile JSON, classify each uniform by its dominant visual effect (luminance, colour, motion, spatial-frequency)
2. **CMC-principled defaults**: apply the mapping table from the design doc — energy→brightness, centroid→lightness, spectral flux→texture, beat→motion, etc.
3. **Emotion-mediated colour**: implement the Palmer 2013 pathway — extract arousal (energy + tempo) and valence (spectral brightness proxy), map to colour palette shifts
4. **Three-tier colour control**: automatic / suggested palettes / manual override
5. **Per-shader mapping profiles**: generate and cache `shader.mapping.json` from the render-probe + CMC layer

---

## The CMC Mapping Table (from design.md)

| Audio feature | Visual parameter type | Basis |
|---|---|---|
| RMS energy | Luminance / brightness | Universal CMC |
| Spectral centroid | Colour lightness | Pitch-brightness correspondence |
| Tempo / BPM | Motion speed | Temporal correspondence |
| Spectral flux (onset strength) | Spatial complexity / texture | Timbre-texture correspondence |
| Beat onset | Scale / pulse events | Rhythmic entrainment |
| Sub-bass energy (band_0) | Low-frequency visual weight | Frequency-size correspondence |
| Arousal (energy + tempo) | Colour warmth / saturation | Palmer et al. 2013 |
| Valence (spectral brightness) | Colour hue / palette | Palmer et al. 2013 |

---

## Uniform Classification

Phase 1 render-probe produces per-uniform metrics:
- `colour_score`: how much the uniform shifts colour distribution
- `motion_score` / `mean_dissimilarity`: how much the uniform creates temporal change
- `luminance_*`: how much the uniform shifts luminance

Classification logic (to implement):
- **luminance-dominant**: high luminance_mean_delta, low colour_score → map to RMS or band energy
- **colour-dominant**: high colour_score, low motion → map to spectral centroid / arousal-valence
- **motion-dominant**: high motion_score → map to beat_phase or spectral flux
- **spatial-frequency**: affects texture density → map to spectral flux or high-band energy
- **mixed**: apply blended mapping

This replaces the current name-heuristic fallback for shaders that have been profiled.

---

## Palmer 2013 — Emotion-Mediated Colour

**Paper**: Palmer, S.E., Schloss, K.B., Xu, Z., & Prado-León, L.R. (2013). Music-color associations are mediated by emotion. *PNAS*, 110(22), 8836-8841.

**Core finding**: music-colour associations arise primarily through shared emotional content (valence and arousal), not direct acoustic-visual mappings. Fast/major/loud music → warm/bright/high-saturation colours because both evoke high arousal/positive valence.

**For Chromaticity**:
- Extract **arousal proxy**: RMS energy (weighted) + normalised BPM when confident
- Extract **valence proxy**: spectral brightness (centroid) — brighter spectrum correlates with "positive" timbre
- Map arousal × valence to a 2D colour palette grid
  - High arousal + high valence: warm, saturated (reds/yellows/oranges)
  - High arousal + low valence: cool saturated (blues/purples — energetic but dark)
  - Low arousal + high valence: light pastels (gentle, positive)
  - Low arousal + low valence: dark, desaturated (ambient, introspective)

**Implementation**: colour temperature and saturation shift applied as a post-processing layer on top of the base uniform mapping. Does not override per-uniform mappings — instead modulates the colour-dominant uniforms.

**Note**: valence from audio is inherently imprecise (key detection is hard, mode/harmony analysis requires more DSP). Phase 3 starts with spectral centroid as a valence proxy. Real harmonic analysis is Phase 4+.

---

## Three-Tier Colour Control

1. **Automatic** (default): emotion-mediated palette from arousal/valence. Runs without user input.
2. **Suggested palettes**: 6-8 named presets (warm/energetic, cool/atmospheric, monochrome, neon, earth, pastel). User picks; system animates within palette bounds.
3. **Manual override**: user selects base hue(s); system handles saturation/brightness animation within that hue.

Phase 3 ships tiers 1 and 2. Manual override is Phase 4 UX.

---

## Phase 3 Architecture

```
Audio features (Phase 2 output)
    ↓
Feature → arousal/valence extraction   [new: emotion_features.py]
    ↓
Render-probe profile (from Phase 1)
    ↓
Uniform classifier                     [new: classifier.py]
    ↓
CMC mapping table                      [new: cmc.py]
    ↓
Palette modulator (emotion-mediated)   [new: palette.py]
    ↓
Final uniform values                   [mapper.py extended]
    ↓
Live renderer (Phase 2, unchanged)
```

---

## Phase 3 Definition of Done

- [ ] `chromaticity/classifier.py` — reads render-probe profile JSON, classifies each uniform
- [ ] `chromaticity/cmc.py` — CMC mapping table, maps classified uniforms to audio features
- [ ] `chromaticity/emotion.py` — arousal/valence extraction from AudioFeatures
- [ ] `chromaticity/palette.py` — three-tier colour control, emotion → palette shift
- [ ] `UniformMapper` updated to use classifier output when profile is available (falls back to heuristic when not)
- [ ] `python -m chromaticity live <shader.glsl>` works with and without a pre-computed profile
- [ ] `python -m chromaticity probe <shader.glsl>` updated to output profile in the format classifier expects
- [ ] Validation: probe + live on 3sySRK, 7cBSDR, XtK3W3 — visual response is perceptually appropriate
- [ ] Tests for classifier, cmc, emotion modules
- [ ] Palmer 2013 arousal/valence mapping documented in `docs/explanation/cmc-mapping.md`
- [ ] CHANGELOG.md updated
- [ ] **Exit criterion met**: 80 preference ratings collected (40 per participant × Xavier + Fletcher), within-subjects counterbalanced AB/BA design — CMC-mapped vs. heuristic-mapped versions of the same stimulus in randomised order

### Exit criterion rationale (agreed 2026-04-21)
Power basis: CMC literature reports d=2.5–3.3 (Palmer 2013 F-values imply Cohen's f≈1.0; RT-based CMC studies report d=2.87–3.28). At d≥2.5, α=0.05, power=0.80: ~5 observations/condition suffices in a within-subjects design. 40 ratings per participant provides a stability buffer well above minimum power requirements. Two expert observers (Xavier + Fletcher, extensive visualiser exposure) are appropriate for this effect size range — perception literature routinely uses n=2–8 for large CMC effects.

---

## Open Questions Before Phase 3 Starts

1. **Render-probe profile format — CRITICAL GAP**: Phase 1 profiles only contain `itime_sensitivity` data (how the shader changes over time). They do NOT contain per-uniform probe data (what happens when you sweep `uBrightness` from 0→1 independently). `uniforms_detected` only shows `["iTime"]` for most shaders. Phase 3 classification requires Phase 1 to be **extended** to sweep custom uniforms and produce per-uniform visual profiles. This is a prerequisite for Phase 3's classification approach. Options:
   - (a) Extend `probe.py` to sweep custom uniforms detected in the GLSL source, recording per-uniform visual signatures → Phase 3 can classify from real data
   - (b) Fall back entirely to name heuristics for Phase 3 classification (already done in Phase 2 mapper) → renders the render-probe profile largely unused for Phase 3
   - (c) Combine: use itime_sensitivity for overall shader characterisation (is this a bright/colourful/motion shader?) and name heuristics for per-uniform mapping
   Option (a) is the right answer but requires Phase 1.5 work before Phase 3. Option (c) is a pragmatic middle ground.

2. **Palmer valence proxy**: is spectral centroid a good enough valence proxy for Phase 3, or do we need something better? Fletcher's call — he knows the literature.

3. **Palette shift implementation**: does the emotion-mediated colour shift happen as a post-processing uniform injection, or as a colour transform in the shader itself? The shader approach requires shader modification (fragile); the uniform approach requires colour-dominant uniforms to be identified by the classifier (depends on Phase 3 classification quality).

4. **Phase 2 heuristic mapper**: should it be kept as a fallback when no profile exists, or replaced entirely? Keep it — graceful degradation for unprobed shaders.

5. **iAudioData texture**: several Shadertoy shaders use `iAudioData` (a 512-sample audio texture) rather than named uniforms. Phase 3 should handle this. Currently unsupported.

---

## Research Reading Before Phase 3 Code

- **Palmer et al. 2013** (PNAS 110:8836) — must read, it's the theoretical foundation
- **Spence 2011** (Attention, Perception, Psychophysics) — CMC review, confirms the mapping table entries
- Review `02-areas/explorations/2026-04-20-emotional-trajectory-cmc.md` — lab's own synthesis on emotional timescales
- Review `02-areas/explorations/2026-04-20-two-layer-matched-filter.md` — two-timescale colour architecture hypothesis

---

## What Phase 3 Is NOT

- Not real harmonic/key analysis (Phase 4+)
- Not per-user calibration of CMC mappings (Phase 4+)
- Not a shader editor or mapping editor UI (Phase 4)
- Not iAudioData texture support (should be in Phase 3 scope — flagged as open question above)
- Not the `--genre` presets doing CMC-aware genre-specific palette selection (future)
