# ADR-001: Render-probe for uniform semantic inference

**Date**: 2026-04-19  
**Status**: Accepted  
**Deciders**: Xavier, Fletcher, Prometheus

## Context

Chromaticity needs to map audio features to shader uniforms without the user manually configuring each parameter. Three approaches were considered:

1. **Name-based heuristics** — infer semantic meaning from uniform names (`uBrightness`, `fSpeed`, etc.)
2. **Render-probe analysis** — sweep each uniform across its range, render frames, classify what changes visually
3. **LLM-assisted** — send shader source + uniform list to a language model, receive semantic labels

## Decision

**Render-probe analysis** (Option 2).

## Rationale

- **Name heuristics**: fast but brittle. Covers ~60% of common patterns; fails on cryptic names (`u_k`, `fParam3`, `t`) which are common in competitive shader art.
- **LLM-assisted**: works well but requires an API call per shader and produces text labels that still need to be mapped to audio features. Adds external dependency to the pre-processing pipeline and is slower than render-probe.
- **Render-probe**: works regardless of uniform naming conventions. Sweeping a uniform and observing visual change (luminance variance, optical flow magnitude, colour histogram shift, spatial frequency change) directly characterises what that uniform does. No external dependencies. Output is a numerical profile that maps cleanly to audio feature dimensions.

## Consequences

- Pre-processing requires a headless OpenGL context (moderngl) — adds a render-capable environment as a dependency
- Render-probe quality depends on the range metadata available for each uniform (GLSL doesn't encode range natively — we rely on Shadertoy's `rangeDef` annotations where present, and default 0–1 otherwise)
- The render-probe output is a feature vector per uniform; CMC mapping is a separate layer (see ADR-003)
- LLM assistance remains available as an *optional* enhancement for labelling — it can annotate the render-probe output with human-readable descriptions, but is not in the critical path
