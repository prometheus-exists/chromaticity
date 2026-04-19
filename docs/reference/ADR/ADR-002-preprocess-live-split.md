# ADR-002: Pre-process / live runtime split architecture

**Date**: 2026-04-19  
**Status**: Accepted  
**Deciders**: Xavier, Fletcher, Prometheus

## Context

Chromaticity must support live performance use. Fletcher's requirement: stability and low latency are first-class. Even if pre-processing is required before a shader is performance-ready, the live path must be rock solid.

## Decision

Strict separation between **pre-processing** (offline, once per shader) and **live runtime** (every frame, ~16ms budget at 60fps).

## Pre-processing responsibilities
- Parse shader GLSL, extract uniforms
- Run render-probe analysis → uniform semantic profile
- Apply CMC mapping → generate `shader.mapping.json`
- (Optional) LLM annotation of uniform labels
- User review/adjustment of mapping (UI TBD)

## Live runtime responsibilities
- Audio capture (sounddevice)
- Feature extraction: FFT bands, beat detection, onset detection, spectral centroid (aubio + numpy, target <1ms)
- Load pre-computed `shader.mapping.json`
- Map audio features → uniform values (lookup + scaling, <0.1ms)
- Inject uniforms → render frame (moderngl)
- No inference, no heavy compute, no network calls

## Rationale

The live loop latency budget is <5ms from audio capture to uniform injection. Any intelligent processing in that path risks frame drops and crashes under stage conditions. Front-loading intelligence into pre-processing eliminates this risk entirely.

## Consequences

- A shader must be "prepared" before it can be used live — one extra step for the user
- Pre-processing can be slow (seconds is fine); live path must be fast (milliseconds required)
- Mapping profiles are cacheable and portable — prepared shaders can be shared between users
- The architecture naturally supports a "library" model: users build up a collection of prepared shaders ready for performance
