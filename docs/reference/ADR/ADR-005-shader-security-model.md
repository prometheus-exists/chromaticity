# ADR-005: Shader security & photosensitivity model

**Date**: 2026-04-19
**Status**: Accepted
**Deciders**: Xavier, Fletcher, Prometheus (surfaced by Hermes audit C2 + C3)

## Context

Chromaticity executes arbitrary GLSL fragment shaders supplied by users (from Shadertoy, local files, or anywhere). This creates two distinct risks:

### Runtime risk (C2)
- Infinite loops or excessively expensive shaders can hang the GPU
- On Windows, TDR (Timeout Detection and Recovery) kills the OpenGL context at ~2 seconds → app crash, potential black-screen
- Malformed shaders can trigger driver bugs — historical record includes black-screens and driver resets on NVIDIA and AMD
- OpenGL has no WebGL-style resource limiting — a shader can request arbitrary texture sizes

### User-safety risk (C3)
- Audio-reactive visuals at kick-drum rates produce brightness transients in the 3-30 Hz range — the photosensitive-seizure trigger band (Harding & Harding 1999; WCAG 2.3 guidance)
- At DnB-typical 170+ BPM, 16th-note sync produces ~11.6 Hz flicker — mid-band, high risk
- Default shaders must be safe to render in public contexts (docs, README previews, live performance to unfamiliar audiences)

A visualiser that crashes the GPU on a bad shader is unshippable. A visualiser that causes seizures is worse.

## Decision

Adopt a **three-layer containment model**:

1. **Process isolation** for render-probe (offline)
2. **Resource & time budgets** for the live runtime
3. **Photosensitivity safety gates** on all output — always on by default, user opt-out per shader

## Layer 1 — Render-probe process isolation (offline)

- Render-probe runs each shader in a **subprocess** with:
  - Hard wall-clock timeout (default 10s per shader, configurable)
  - Soft per-frame budget (default 500ms; exceeding it logs a warning, doesn't kill)
  - Memory cap via platform-specific APIs (`resource.setrlimit` on POSIX, job objects on Windows)
  - No filesystem write access outside a scratch directory
  - No network access

- On timeout, the subprocess is killed with SIGKILL (POSIX) / TerminateProcess (Windows). The parent records a failure entry in the mapping profile (`probe.status: "timeout"`) and continues to the next shader.

- Subprocess crash does not crash the parent. Parent uses `subprocess.Popen` with careful stream management to avoid deadlock on stdout/stderr.

- **Implementation path**: `chromaticity.probe.isolated_runner` — a thin wrapper around `subprocess` + `moderngl` that can be invoked as `python -m chromaticity.probe.isolated_runner <shader_path>`.

## Layer 2 — Live runtime budgets

The live engine cannot tolerate a shader crash or hang during performance. Mitigations:

- **Frame deadline**: target 16.67ms (60Hz) / 8.33ms (120Hz). Soft limit. If exceeded, log and continue.
- **Hang detection**: if a frame exceeds 5x the target deadline, the engine assumes the GPU context is compromised. It:
  1. Drops the current shader
  2. Falls back to the last known-good shader or a black-frame safety buffer
  3. Logs the failure with full context
  4. Attempts GPU context recovery on a background thread
- **Pre-flight check**: before a shader enters the live loop, its render-probe profile must be present and its `probe.status == "ok"`. Untested shaders cannot be loaded live.
- **Memory budget**: hard cap on total GPU memory usage across all loaded shaders. Default 512MB, configurable.

This is not sandboxing. It is **crash recovery**. The goal is: *when a shader fails, the visualiser survives, the performance continues, and the performer isn't staring at a black screen or crashed window*.

## Layer 3 — Photosensitivity safety (always on)

### Constraints (default-on, user can override per-shader with explicit acknowledgment)

- **Flicker rate cap**: maximum brightness oscillation rate = 3 Hz by default
- **Brightness delta cap per frame**: maximum luminance change between consecutive frames at 60fps = 25% (prevents rapid strobing even at permitted low frequencies)
- **Red flash guard**: full-red flashes at >3 Hz are flagged as WCAG 2.3.1 non-compliant and blocked unless user opts out
- **Three-flash rule**: no more than three flashes within any one-second window (WCAG 2.3.1)

### Enforcement

- **Render-probe computes** `safety.flicker_rate_max_hz` and `safety.brightness_delta_max_per_frame` for each shader under realistic audio inputs (a synthetic "aggressive kick" test signal during probing)
- **Live runtime enforces** the caps by:
  - Low-pass filtering the uniforms driving brightness if they approach rate limits
  - Interpolating between frames if brightness delta exceeds cap
- **README and UI warnings** for any shader whose profile shows `harding_compliant: false`

### User override

- A user can opt out of safety gates per-shader with an explicit action (checking a "I understand this shader is not safe for photosensitive audiences" box)
- Override is stored in the user's local profile, not in the shader's mapping profile
- Override never applies to default/demo shaders — those are locked-safe

## Consequences

- **Render-probe is slower**: subprocess overhead adds ~100-200ms per shader. Acceptable; probing is offline.
- **Live runtime must watch its own vitals**: adds a monitor thread. Small overhead, significant safety benefit.
- **Every shader profile carries safety metadata**: decoupled from live-runtime code so safety enforcement is data-driven, not hardcoded.
- **Default shaders must pass Harding test**: this constrains what we can ship as examples. Acceptable — the demo shaders represent the product.
- **Opt-out requires explicit user acknowledgment**: more friction than Synesthesia, but defensible. A visualiser that silently caused a seizure would be an unrecoverable PR and ethical failure.

## Test plan

- Unit tests: flicker detector identifies known-unsafe synthetic signals (hand-crafted 10 Hz square waves)
- Integration tests: known-bad Shadertoy shaders (infinite loops from GitHub issue archives) terminate cleanly in render-probe
- Fuzz test: random GLSL generation with malformed inputs — parent process never crashes
- Harding-test validator: run the Trace-Media compliance algorithm on probe output (there's a BSD-licensed reference implementation)

## Alternatives considered

### A: No sandboxing, "trust the user"
Rejected. First malformed Shadertoy shader hangs the pipeline. Not acceptable for live performance.

### B: Full WebGL-style sandbox
Rejected. Huge engineering investment. OpenGL doesn't support WebGL's validator model. Would mean shipping Chromium or similar. Out of scope.

### C: Warning-only photosensitivity (opt-in safety)
Rejected. A visualiser that defaults to unsafe is wrong. Friction should be on the unsafe path, not the safe one.

### D (chosen): Three-layer defence (isolation + budgets + safety-by-default)
Accepted. Each layer has a specific failure mode it addresses. Combined, they give us a visualiser that survives bad input and doesn't harm users.
