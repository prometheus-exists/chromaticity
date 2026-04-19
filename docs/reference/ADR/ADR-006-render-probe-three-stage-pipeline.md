# ADR-006: Render-probe — three-stage inference pipeline

**Date**: 2026-04-19
**Status**: Accepted
**Deciders**: Xavier, Fletcher, Prometheus (surfaced by Hermes audit D1)

## Context

ADR-001 committed to render-probe (sweeping each uniform, rendering frames, measuring visual response) as the mechanism for inferring what each shader uniform controls. That decision is still sound — it works for cryptic uniform names and non-standard shaders where nothing else will.

But render-probe is expensive: GPU time, driver variance, per-shader latency of seconds. Applying it to *every* uniform in *every* shader is wasteful when:
- Shadertoy has standard uniforms (`iTime`, `iResolution`, etc.) with known semantics
- Many user shaders name uniforms descriptively (`speed`, `color`, `intensity`, `brightness`)
- GLSL source context often reveals a uniform's role (it's only used inside `gl_FragColor.rgb *= u_mod`)

ADR-001 focuses on *when* render-probe runs. This ADR refines *how* uniform inference proceeds when render-probe alone is too blunt.

## Decision

Uniform role inference runs as a **three-stage pipeline**, shortest-path first:

1. **Stage 1 — Name heuristic** (no GPU, <1ms per uniform)
2. **Stage 2 — Source analysis** (no GPU, <10ms per uniform)
3. **Stage 3 — Render-probe** (GPU, 100-500ms per uniform, expensive path)

Stages 1 and 2 emit *evidence entries* into the mapping profile (per ADR-004). Stage 3 runs only on uniforms where Stage 1+2 confidence is below a threshold (default 0.6) OR where high coverage is explicitly requested (user flag `--full-probe`).

## Stage 1 — Name heuristic

Input: uniform name + GLSL type.

Process: match against a **curated dictionary** of known conventions:
- Shadertoy standard: `iTime`, `iResolution`, `iMouse`, `iChannel*`, `iDate`, `iFrame` — high confidence, well-defined roles
- Common patterns: `time`, `speed`, `color`, `colour`, `brightness`, `intensity`, `scale`, `rotation`, `hue`, `saturation`, `zoom`, `pulse`, `freq`, `frequency`, `wave`, `amp`, `amplitude` — medium-high confidence
- Prefixed patterns: `u_*`, `v_*`, `f*`, `i*` — stripped and re-matched
- CamelCase splitting: `audioEnergy` → [`audio`, `energy`]

Output: evidence entry with `stage: "name_heuristic"`, weight proportional to match strength.

**Coverage estimate**: ~60% of Shadertoy shaders have at least one name-heuristic match.

**Fletcher contribution path**: this dictionary is pure data. Fletcher can propose additions or corrections via GitHub PR without writing Python. It lives at `chromaticity/probe/name_dictionary.json`.

## Stage 2 — Source analysis

Input: full GLSL source + uniform name + uniform type.

Process: lightweight static analysis (regex + simple AST, no full GLSL parser required):
- Find every line where the uniform appears
- Classify usage context: `*=` (modulation), `+=` (offset), `mix(..., u)` (interpolation factor), inside `texture()` (sampler coordinate), inside `rotate()` / matrix constructor (rotation), etc.
- Colour context: does the uniform appear in `gl_FragColor` or `fragColor` assignments? In `.rgb` multiplications? These strongly imply colour/brightness roles.
- Motion context: does the uniform interact with `iTime` or `vUv` coordinates? Implies motion/position roles.

Output: evidence entries, each with a cited source line and a weight.

**Coverage estimate**: Stage 1 + Stage 2 together cover ~80% of Shadertoy shaders to confidence ≥ 0.6.

**Implementation note**: we do NOT write a full GLSL parser. Regex + heuristics + known idioms. If the analysis is wrong, Stage 3 corrects it.

## Stage 3 — Render-probe

Input: uniform name, GLSL type, probed range (from source analysis), full shader.

Process: **only runs if Stage 1+2 confidence < threshold, OR uniform role is high-ambiguity**:
- Sweep the uniform across its range (linear or log, 32 samples default)
- Render each frame at fixed `iTime` to isolate the effect of this uniform
- Measure visual deltas:
  - Luminance variance (brightness role)
  - Colour histogram shift (hue/saturation role)
  - Optical flow magnitude (motion role — sweep against a time-advanced reference)
  - Spatial frequency spectrum (texture/detail role)
  - Global position centroid (position/offset role)
- Classify the response profile via a simple rule set or small classifier

Output: evidence entries from observed response, typically with high weight when clear.

**This is where ADR-005's subprocess isolation lives**. Stage 3 is the only stage that touches the GPU and the only stage that can time out.

## Confidence aggregation

Each uniform's final `inferred_role` + `confidence` is computed by aggregating the evidence list:

```
confidence = weighted_combination_with_agreement_bonus(evidence_list)
inferred_role = argmax(role → sum_of_weights_for_role)
```

If evidence conflicts across stages (Stage 1 says "brightness", Stage 3 says "rotation"), confidence is reduced and the conflict is logged. High-conflict uniforms are candidates for manual review.

## Consequences

### Speed & scalability
- A typical Shadertoy shader with 5 uniforms: ~5-20ms for Stages 1+2. Only 1-2 uniforms typically reach Stage 3. Total shader analysis time drops from "seconds per shader" to "<100ms typical, <2s worst case."
- Batch-analysing 100 Shadertoy shaders becomes practical (<5 minutes) vs painful (>30 minutes pure render-probe).
- CI can run Stages 1+2 without GPU runners. Only Stage 3 validation tests need GPU CI.

### Quality
- Pure render-probe gets fooled by shaders where a uniform's visual effect depends on other uniforms' values. Stage 2's source analysis catches these dependencies before we probe.
- Conversely, pure name heuristics fail on cryptic names. Stage 3 saves us.
- The combined pipeline is more robust than any single stage.

### Fletcher's contribution path
- **Stage 1 dictionary** is editable JSON. Fletcher can add/refine entries without Python knowledge. "I've seen `aExp` mean `audio exposure` in several house-music shaders" → dictionary entry.
- **Stage 2 heuristics** are Python but well-commented; Fletcher can suggest via issue.
- **Stage 3** is the engineering work — Fletcher reviews outputs, not code.

### Storage per mapping profile
- The evidence list may get long for ambiguous uniforms. Acceptable — JSON compresses well, and the evidence is valuable audit trail for the "perceptually principled" claim.

## Test plan

- **Stage 1 regression tests**: snapshot the dictionary and test against a known-good corpus of Shadertoy uniform names
- **Stage 2 unit tests**: hand-crafted GLSL with known uniform roles; source analysis matches expected classifications
- **Stage 3 golden tests**: a small set of test shaders with hand-annotated expected mappings; render-probe output must match (with tolerance per ADR-005 determinism considerations)
- **Pipeline integration test**: `brotherdurry-constancy.mp3` + a set of test shaders → full pipeline → valid mapping profile conforming to ADR-004 schema

## Alternatives considered

### A: Pure render-probe (ADR-001 as-stated)
Partially superseded. Render-probe is still the bedrock for hard cases, but running it blindly on every uniform is wasteful.

### B: Stage 1 only (name heuristics)
Rejected. Too brittle. 40% of Shadertoy shaders use cryptic names where heuristics fail.

### C: Stage 3 only (pure render-probe)
Rejected. Expensive, slow, fooled by inter-uniform dependencies.

### D: LLM-based source analysis in place of Stage 2
Rejected for Phase 1. Adds external API dependency, cost, and variance. Regex + heuristics are deterministic and free. Revisit in Phase 3+ if a local small-model pass adds genuine value.

### E (chosen): Three-stage pipeline with confidence aggregation
Accepted. Best coverage-per-compute trade. Naturally scales from "just use obvious names" to "probe the GPU when we must."

## Timebox

Hermes flagged that render-probe is the most likely component to consume unbounded time. Explicit timeboxes:

- **Stage 1**: 3 days from Phase 1 kickoff (dictionary + matcher + tests)
- **Stage 2**: 5 days (source analyser + classifiers + tests)
- **Stage 3**: 7 days (renderer wrapper + sweep logic + visual delta measurements)
- **Integration**: 3 days (pipeline + confidence aggregation + end-to-end tests)

Total: ~3 weeks of effective engineering to Phase-1-complete. If we exceed this, stop and reassess — the project design is wrong or the scope needs trimming.
