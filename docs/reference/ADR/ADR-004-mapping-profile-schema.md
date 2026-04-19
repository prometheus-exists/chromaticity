# ADR-004: Mapping profile JSON schema

**Date**: 2026-04-19
**Status**: Accepted
**Deciders**: Xavier, Fletcher, Prometheus (surfaced by Hermes audit I1)

## Context

A shader's "mapping profile" is the contract between render-probe (offline analysis) and the live runtime. It describes, for each uniform in a GLSL shader, what that uniform controls visually and which audio feature should drive it.

Without a locked schema:
- render-probe output is unvalidated
- the live engine has no contract to consume
- contributors (especially Fletcher, who works in JSON not Python) cannot propose mappings
- versioning becomes impossible once files are in the wild
- "perceptually principled" is unenforceable (no place to store evidence citations)

## Decision

Define the mapping profile schema now, before any code. All render-probe output and all live-engine input conform to this schema. Schema versioned via `schema_version` field. Breaking changes require a new ADR.

## Schema (v0.1.0)

```json
{
  "schema_version": "0.1.0",
  "shader": {
    "source_ref": "shadertoy:XXXXXX | local:path/to/shader.glsl | https://...",
    "source_sha256": "hex digest of normalised GLSL source",
    "title": "human-readable name",
    "author": "attribution if known, else null"
  },
  "probe": {
    "probe_version": "semver of render-probe that generated this",
    "probed_at": "ISO8601 timestamp",
    "platform": {
      "os": "macOS 14.5 | Windows 11 22H2 | ...",
      "gpu": "Apple M2 | NVIDIA RTX 4090 | ...",
      "driver": "driver version string or null",
      "opengl_version": "4.6 Core | ...",
      "renderer": "moderngl-probe | mesa-llvmpipe | ..."
    },
    "probe_params": {
      "resolution": [512, 512],
      "frames_per_sweep": 32,
      "sweep_domain": "linear | log | custom"
    }
  },
  "uniforms": {
    "<uniform_name>": {
      "glsl_type": "float | vec2 | vec3 | vec4 | int | bool | sampler2D",
      "standard": "iTime | iResolution | iMouse | iChannel0 | ...  (null if user-defined)",
      "probed_range": [min, max],
      "inferred_role": "brightness | hue | saturation | motion_speed | spatial_frequency | scale | rotation | position | texture_complexity | color_palette_index | unknown",
      "confidence": 0.0,
      "evidence": [
        {
          "stage": "name_heuristic | source_analysis | render_probe",
          "signal": "matched token 'brightness'; luminance_delta=0.73; ...",
          "weight": 0.0
        }
      ],
      "suggested_audio_feature": "rms_energy | spectral_centroid | spectral_flux | tempo | beat_pulse | sub_bass_energy | onset | valence | arousal | none",
      "rationale": "cited evidence or explicit 'heuristic' marker",
      "rationale_ref": "ADR-NNN | doi:10.xxxx | null",
      "mapping_curve": "linear | log | exponential | step",
      "sensitivity": 1.0,
      "user_override": null
    }
  },
  "colour_model": {
    "mode": "auto | override",
    "palette": null,
    "arousal_mapping": "default | custom",
    "valence_mapping": "default | custom"
  },
  "safety": {
    "flicker_rate_max_hz": 3.0,
    "brightness_delta_max_per_frame": 0.25,
    "harding_compliant": true
  }
}
```

## Field semantics

### `schema_version`
Semver. Minor version bumps are additive (new optional fields). Major version bumps require migration.

### `shader.source_sha256`
Normalised GLSL source hash. Normalisation strips comments and whitespace. Two shaders with the same sha256 are treated as identical (mapping cache key).

### `uniforms.<name>.inferred_role`
Closed vocabulary (enum). Expandable via new ADR. `unknown` is a valid value — better than forcing a guess.

### `uniforms.<name>.evidence`
List of all signals that contributed to the inference. Each entry names its stage (see ADR-006 for stage definitions), the signal found, and a weight in [0,1]. Confidence is computed from weighted aggregation, not stored as a single magic number.

### `uniforms.<name>.suggested_audio_feature`
The default audio feature driving this uniform. Closed vocabulary, expandable via ADR. `none` is valid — some uniforms should not react to audio (e.g. UI offsets).

### `uniforms.<name>.rationale` + `rationale_ref`
**This is the "perceptually principled" enforcement mechanism** (per Hermes D3). Every mapping must either cite specific evidence (DOI / ADR reference) or explicitly say `"heuristic"` — no silent hand-waving.

### `uniforms.<name>.user_override`
If non-null, the user has customised this mapping. Contains `{audio_feature, sensitivity, curve}` to override the suggestions. The suggestions remain in place so the system can distinguish "default applied" from "user prefers this."

### `colour_model`
Top-level (not per-uniform) because colour control is usually global to a shader. Addresses Fletcher's pain point about Synesthesia's rigid colour schemes.

### `safety`
Photosensitivity guardrails. Every shader profile asserts its compliance. Values populated by render-probe during its sweep (does this shader produce >3Hz flicker at realistic audio inputs?). Consumed by live runtime as hard limits. See ADR-005 (forthcoming).

## Consequences

- **Phase 1 deliverable becomes concrete**: render-probe produces JSON conforming to this schema. Tests validate against the schema. Done.
- **Fletcher can contribute from day one**: he doesn't need to write Python. He can review/propose mappings by editing JSON on GitHub.
- **Cache-friendly**: `shader.source_sha256` is the cache key. Re-probing a shader is only needed if source changes.
- **Audit trail**: every mapping has traceable evidence. Hostile reviewers can check that our "perceptually principled" claim is enforced, not decorative.
- **Platform-tagged**: the `probe.platform` field means the same shader can have multiple profiles if render-probe outputs vary across GPUs (see ADR-006 render-probe determinism).
- **Safety is first-class**: every profile carries its own safety metadata. Live runtime doesn't need to reinfer safety at load time.

## Schema evolution

v0.1.x: additive only (new optional fields)
v0.2.x: renames and deprecations (with migration)
v1.0.0: once we ship a stable release

Migration scripts live in `scripts/migrate_mapping_profile/`. Old profiles are read-only; migrated on read.

## Alternatives considered

### A: Start implementation; let the schema emerge
Rejected. Leads to "each component invents its own dict shape" failure mode. Refactoring data contracts late is expensive.

### B: Use Python dataclasses as schema
Rejected. Binds schema to Python. Fletcher contributes via GitHub JSON editing; dataclasses don't render well there. JSON Schema is editor/LSP-friendly.

### C: Use a minimal schema now, expand later
Partially adopted. v0.1.0 is minimal relative to what we'll eventually need (no LFO parameters, no conditional mappings, no scene-level state). But every field present now is load-bearing. Future additions are extensions, not corrections.
