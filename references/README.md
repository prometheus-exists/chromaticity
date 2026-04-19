# Chromaticity — Reference Repositories

Generated: 2026-04-19  
Full prior art analysis: `02-areas/topic-reviews/chromaticity-prior-art-opensource.md`

---

## Tier 1 — Study Architecture

### BrokenSource/ShaderFlow
- **URL**: https://github.com/BrokenSource/ShaderFlow
- **License**: AGPL-3.0
- **Why**: Closest public equivalent to Chromaticity. Python + moderngl + sounddevice. Modular audio-reactive GLSL shader engine. Study their audio module (FFT→texture pipeline), scene composition system, and uniform naming conventions. The gap: no perceptual mapping layer.

### panxinmiao/shadertoy
- **URL**: https://github.com/panxinmiao/shadertoy
- **License**: MIT
- **Why**: Cleanest Python Shadertoy API. `snapshot()` returns numpy array — the exact primitive needed for Chromaticity's render-probe offline pipeline. `set_shader_state(time=N, ...)` for parameterised rendering. `DataChannel` for numpy→texture injection. wgpu-py backend (WebGPU).

### patriciogonzalezvivo/glslViewer
- **URL**: https://github.com/patriciogonzalezvivo/glslViewer
- **License**: BSD-3-Clause
- **Why**: Parses uniforms from GLSL source automatically. Accepts uniform injection via OSC + stdin. Headless rendering mode. Audio texture support. These together are the architectural building blocks of Chromaticity's live uniform pipeline and render-probe system. C++ CLI tool, not Python, but architecture is directly transferable.

---

## Tier 2 — Reference / Pattern Borrow

### projectM-visualizer/projectm
- **URL**: https://github.com/projectM-visualizer/projectm
- **License**: LGPL-2.1
- **Why**: The canonical audio-reactive visualiser. Study the `bass/mid/treb/vol` semantic audio band paradigm — this is the design vocabulary that Chromaticity's user-facing uniform names should map to or extend. Also: the MilkDrop preset `.milk` format shows 20 years of accumulated wisdom about which audio features map well to which visual parameters.

### aubio/aubio
- **URL**: https://github.com/aubio/aubio
- **License**: GPL-3.0
- **Why**: The live audio analysis library Chromaticity uses. Low-latency C backend, Python bindings. Onset, beat tracking, MFCC, FFT, filterbank. Confirmed as correct choice over alternatives for live DnB performance.

### CPJKU/madmom
- **URL**: https://github.com/CPJKU/madmom
- **License**: BSD (source), CC BY-NC-SA (models — non-commercial)
- **Why**: Best beat tracking accuracy (RNN DBNBeatTracker). Use offline for pre-analysing DnB tracks to build accurate beat grids. Useful for the render-probe pipeline when timing-accurate analysis is needed. NC model license means offline/analysis only.

### librosa/librosa
- **URL**: https://github.com/librosa/librosa
- **License**: ISC
- **Why**: Gold standard offline audio analysis. `librosa.beat.beat_track()`, `spectral_centroid()`, harmonic/percussive separation, onset detection. Use in render-probe pipeline for rich feature extraction from test audio clips. Not suitable for live streaming.

### aiXander/Realtime_PyAudio_FFT
- **URL**: https://github.com/aiXander/Realtime_PyAudio_FFT
- **License**: MIT
- **Why**: Clean reference implementation of the FIFO buffer + stream_reader/stream_analyzer pattern for live audio FFT. The code is simple enough to read completely. The PyAudio ↔ sounddevice abstraction pattern is useful.

---

## Tier 3 — Output / Integration

### kushiemoon-dev/OpenDrop-VJ
- **URL**: https://github.com/kushiemoon-dev/OpenDrop-VJ
- **License**: Personal/educational only
- **Why**: Best example of a modern VJ output chain: glReadPixels → Spout/v4l2/NDI → OBS. The sidecar renderer architecture (separate OpenGL process per deck, JSON IPC) is relevant when Chromaticity needs to output to broadcast tools.

### leadedge/Spout2
- **URL**: https://github.com/leadedge/Spout2
- **License**: BSD-2-Clause
- **Why**: Windows-side OpenGL texture sharing. `pip install SpoutGL` gives Python bindings. When Chromaticity needs to send frames to OBS or other VJ software on Windows.

### scheb/sound-to-light-osc
- **URL**: https://github.com/scheb/sound-to-light-osc
- **License**: MIT
- **Why**: Minimal example of the live beat detection → external signal pipeline. The "music intensity" state machine (calm/normal/intense based on energy history) is a useful macro-state layer concept for controlling which cluster of uniform mappings is active.

---

## Notable Non-Starters

| Repo | Why Ignored |
|------|-------------|
| FreeJ | Abandoned (2010s). GTK-based. No relevance. |
| GStreamer vizplugins | C-only, plugin architecture only. |
| Libvisual | C framework, unmaintained for Python use. |
| pulseviz.py | Linux/PulseAudio only, 2021. |
| nicoguaro/pysynes | Toy colour↔pitch mapping. Not production-ready. |

---

## Confirmed Gaps (Chromaticity's novel space)

No existing open-source project implements:
1. **Render-probe pipeline** — automated visual parameter analysis for GLSL shaders (vary uniforms systematically, measure visual response, fit curves)
2. **CMC-principled audio→visual mappings** — no code implementations of cross-modal correspondence mappings in any visualiser
3. **Perceptually-calibrated uniform discovery** — the combination of offline probing + CMC theory to produce live DnB mappings

Chromaticity builds above the available primitives (aubio, moderngl, ShaderFlow's pattern) with an entirely original perceptual mapping layer.
