# Phase 3 Spec — CMC-Principled Mapping Integration

**Status**: Draft (2026-04-21, revised post-Hermes Phase 3 review)
**Authors**: Prometheus, Xavier, Fletcher Hammond
**Resolved**: Hermes Phase 2 sign-off complete (PASS WITH CONDITIONS). Phase 2 MUST fixes applied (v0.3.0). Spectral centroid as valence proxy approved by Fletcher. Exit criterion agreed (80 ratings, 40/participant).
**Pending**: Stimulus set selection (Xavier + Fletcher input required — see §Questions), evaluation isolation decision, Palmer 2013 read before CMC mapping code

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

**Core finding**: music-colour associations arise primarily through shared emotional content (valence and arousal), not direct acoustic-visual mappings. The mechanism: fast/loud music evokes high arousal; major key evokes positive valence. High-arousal emotions and positive-valence emotions are independently associated with warm/saturated colours. Arousal and valence are separable axes — fast/loud does NOT imply positive valence, and major key does NOT imply high arousal.

**For Chromaticity**:
- Extract **arousal proxy**: `arousal = 0.7 × norm_rms + 0.3 × tempo_confidence × norm_bpm`
  where `norm_rms = rms / rms_ref` (running 95th-percentile reference), `norm_bpm = (bpm − 60) / 140`, both clamped [0, 1]. Weights w_rms=0.7, w_bpm=0.3 are tuneable. RMS dominates because it responds at beat timescale; BPM contributes sustained phrase-level modulation when tempo is stable.
- Extract **valence proxy**: spectral brightness (centroid) — brighter spectrum correlates with "positive" timbre (Hailstone et al. 2009, Eerola et al. 2009).
  ⚠️ **Known limitation**: centroid is mode-blind. Bright minor-key or dissonant music will be miscoded as positive valence. Tracks where this proxy fails: dark/neurofunk DnB, industrial, bright atonal content. Stimulus selection must avoid these for evaluation validity (see §Evaluation Design).
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

## Phase 3 Evaluation Instrument

**Design**: Within-subjects, AB/BA counterbalanced. CMC-mapped vs. heuristic-mapped versions of the same stimulus, presented in randomised order. 5 stimulus pairs per session × 8 items = 40 ratings per participant. 2 participants (Xavier + Fletcher) = 80 total.

**Scale**: 7-point Likert. 1 = Not at all, 7 = Perfectly.

**Item presentation**: Items randomised within each stimulus block (no fixed dimension order). Free-text notes field after each block — optional, not required to proceed. No attention check items.

**Scoring**: Reverse-code L2, C2, M2, O2 using formula **(8 − score)**. A score of 7 (strongest agreement with a negative statement) becomes 1; a score of 1 becomes 7. Average within each dimension for subscale scores. Average all 8 items for overall cohesiveness score.

### Items

| ID | Item | Direction |
|----|------|-----------|
| L1 | The brightness of the visuals matches the energy of the music. | Forward |
| L2 | The visuals stay bright even when the music is quiet or subdued. | **Reverse** |
| C1 | The colours feel emotionally appropriate for what the music expresses. | Forward |
| C2 | The colour palette feels disconnected from the mood of the music. | **Reverse** |
| M1 | The speed and rhythm of the visual movement matches the music. | Forward |
| M2 | The visuals move at a pace that feels unrelated to the music's tempo or pulse. | **Reverse** |
| O1 | The visuals and music feel like they belong together. | Forward |
| O2 | Watching the visuals while listening to the music feels disconnected or arbitrary. | **Reverse** |

### Subscale structure

| Subscale | Items | Maps to CMC dimension |
|----------|-------|----------------------|
| Luminance | L1, L2(R) | RMS energy → brightness |
| Colour | C1, C2(R) | Arousal/valence → palette |
| Motion | M1, M2(R) | Beat phase / spectral flux → movement |
| Overall cohesiveness | O1, O2(R) | Composite |

### Session structure

1. Load stimulus (labelled “Condition A” or “Condition B” — labels randomised per participant/session, no descriptive names)
2. Play for 60 seconds
3. Present 8 items in randomised order
4. Optional free-text notes
5. Repeat for all stimuli in this session
6. Separate session: same stimuli in opposite condition (AB/BA counterbalanced across participants)

**Blinding note**: Full double-blind is not achievable with 2 expert co-developers as participants. The condition labels (A/B) are neutral and randomised, but demand characteristics cannot be fully eliminated. Treat this as expert formative evaluation; note the blinding limitation explicitly in any write-up.

---

## Phase 3 Definition of Done

- [ ] `chromaticity/classifier.py` — reads render-probe profile JSON, classifies each uniform
- [ ] `chromaticity/cmc.py` — CMC mapping table, maps classified uniforms to audio features
- [ ] `chromaticity/emotion.py` — arousal/valence extraction from AudioFeatures (note: DoD and architecture both use `emotion.py` — canonical name)
- [ ] `chromaticity/palette.py` — three-tier colour control, emotion → palette shift
- [ ] `UniformMapper` updated to use classifier output when profile is available (falls back to heuristic when not)
- [ ] `python -m chromaticity live <shader.glsl>` works with and without a pre-computed profile
- [ ] `python -m chromaticity probe <shader.glsl>` updated to output profile in the format classifier expects
- [ ] Validation: probe + live on evaluation shader set — visual response is perceptually appropriate
- [ ] Evaluation classifications documented: for each evaluation shader, which uniform classifications are manually verified vs. heuristic-inferred
- [ ] Tests for classifier, cmc, emotion modules
- [ ] Palmer 2013 arousal/valence mapping documented in `docs/explanation/cmc-mapping.md`
- [ ] Photosensitive safety mode (3Hz flicker cap) implemented — committed in STANDARDS.md for Phase 2+, safety regression until shipped
- [ ] Colour pipeline extended: `palette.py` returns `dict[str, tuple[float, float, float]]` for colour-dominant uniforms; render loop merges with scalar mapper output
- [ ] CHANGELOG.md updated
- [ ] **Pilot gate**: 10 ratings from 1 participant before full data collection. Check for floor/ceiling effects and item variance.
- [ ] **Exit criterion met**: 80 preference ratings collected (40 per participant × Xavier + Fletcher), within-subjects counterbalanced AB/BA design, neutral condition labels (A/B)

### Exit criterion rationale (agreed 2026-04-21)
Power basis: CMC literature reports d=2.5–3.3 (Palmer 2013 F-values imply Cohen's f≈1.0; RT-based CMC studies report d=2.87–3.28). At d≥2.5, α=0.05, power=0.80: ~5 observations/condition suffices in a within-subjects design. 40 ratings per participant provides a stability buffer well above minimum power requirements. Two expert observers (Xavier + Fletcher, extensive visualiser exposure) are appropriate for this effect size range — perception literature routinely uses n=2–8 for large CMC effects.

---

## Questions for Xavier + Fletcher (blocking)

These need answers before the evaluation design can be finalised. The rest of Phase 3 implementation can proceed in parallel.

**Q1 — Stimulus set (most important):**
We need 5 tracks (or 10 for no-repetition design — see Q2). Each track must have:
- Dynamic energy range (loud/quiet sections, so L1/L2 can be tested)
- Clear rhythmic pulse (so M1/M2 can be tested)
- Timbral variation (so spectral centroid changes meaningfully over the track)
- Centroid-valence validity: bright sections should feel positive/uplifting; dark sections should feel heavy/tense. **Tracks where bright = aggressive/dissonant should be excluded** (centroid proxy will be wrong).

Candidates? You can nominate tracks from Fletcher's library or other sources. For each: name, rough BPM, genre, and whether you think the brightness-positivity correlation holds.

**Q2 — Repetition vs. no-repetition design:**
Hermes flagged that showing each participant the same track twice (CMC condition + heuristic condition) creates carryover — the second viewing isn't perceptually naive. Two options:
- **5 tracks × 2 conditions = 10 stimulus exposures per participant** (current plan, some carryover risk)
- **10 tracks × 1 condition each = 10 stimulus exposures per participant** (no repetition, cleaner, but needs 10 tracks and one participant sees CMC on tracks 1-5 and heuristic on tracks 6-10 — different stimuli per condition)

Which design is better for your purposes?

**Q3 — Evaluation isolation:**
Hermes recommends isolating the colour manipulation: test CMC-colour vs. heuristic-colour with brightness (L) and motion (M) held constant between conditions. This makes the Colour subscale the primary outcome and the result interpretable ("CMC colour mapping is better" rather than "something about CMC is better"). The cost: you're not testing the full CMC package, just the colour layer.

Alternative: test the full CMC mapping vs. full heuristic, accept that the result is a composite, and treat the subscale scores as exploratory breakdowns.

Which serves your goals better?

**Q4 — One shader or multiple:**
Hermes recommends fixing one shader for the quantitative evaluation to eliminate shader as a confound (i.e. all 5/10 tracks played over the same shader). This lets you say "CMC is better on shader X" cleanly. Using multiple shaders adds a shader confound.

Is there one shader you want to be the primary evaluation shader? (3sySRK, 7cBSDR, or XtK3W3 are the profiled candidates.)

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
