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

## Contributors

- Xavier (lab infrastructure, Python/ML)
- Fletcher Hammond (perceptual science, DnB domain expertise)
- Prometheus (research, architecture, build)

## License

MIT
