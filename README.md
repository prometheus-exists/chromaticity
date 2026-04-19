# Chromaticity

**Perceptually-principled audio-reactive visualiser for live music performance.**

Bring your own shaders. No paywall. No marketplace. Just music and light.

## What it is

Chromaticity takes any GLSL shader (Shadertoy-compatible) and makes it audio-reactive using principles from cross-modal correspondence research — the science of how sound and vision relate in human perception.

Most shaders on Shadertoy are visually stunning but silent. Chromaticity analyses a shader's parameters, infers what each one controls (brightness, motion speed, spatial frequency, colour), and maps audio features to those parameters using perceptually principled defaults. Load a shader, play music, perform.

## What it is not

- Not a marketplace (bring your own shaders, no subscription)
- Not AI-native (AI is used to *build* it, not as a runtime dependency)
- Not a full VJ suite (Resolume exists for that)

## Target use case

Live performance. Stability and low latency are first-class requirements.

## Architecture

**Pre-processing**: when a shader is loaded, Chromaticity sweeps each uniform across its range, observes what changes visually (render-probe analysis), and generates a CMC mapping profile. This happens once, offline.

**Live runtime**: audio capture → FFT + beat detection → uniform injection → render. ~1ms pipeline, no inference in the loop.

## Status

Early development. See [CHANGELOG.md](CHANGELOG.md) for current state.

## Documentation

- [Standards](docs/STANDARDS.md) — coding standards, Definition of Done
- [Design](docs/explanation/design.md) — why it's built this way
- [ADRs](docs/reference/ADR/) — architecture decisions
- [Vocabulary](docs/reference/vocabulary.md) — shared glossary (perception × GLSL × music)
- [GLSL for Perception Scientists](docs/tutorials/glsl-for-perception-scientists.md) — if you know perception but not shaders
- [Non-code contribution guide](docs/how-to/non-code-contribution.md) — how to contribute without writing Python
- [Contributing](CONTRIBUTING.md) — developer-focused contribution standards
- [Tasks](TASKS.md) — open work + known trade-offs

## Accessibility

Chromaticity includes a **photosensitivity-safe mode** that limits temporal luminance changes to stay below clinical and WCAG 2.3.1 thresholds (3–30 Hz flash-rate danger zone). Most visualiser software is architecturally unable to offer this; Chromaticity's mapping layer sits between audio and visuals, so it can attenuate dangerous temporal patterns *without destroying the shader's aesthetic*.

Until the runtime flicker limiter ships (Phase 2), default shaders and demos are manually vetted. Use with care in public-facing contexts outside the default set. See ADR-005 for the full safety model.

## Contributors

- Xavier Butler (lab infrastructure, Python/ML)
- Fletcher Hammond (perceptual science, music domain expertise)
- Prometheus (research, architecture, build)

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to get involved.

## License

MIT (see `LICENSE`). All dependencies are MIT/BSD/ISC/Apache-2.0 permissive licenses. No GPL, AGPL, LGPL, or non-commercial-restricted components. See `docs/reference/ADR/ADR-003-mit-permissive-licensing.md` for rationale.
