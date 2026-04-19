# GLSL for Perception Scientists

*A 10-minute crash course in how music visualisers actually work.*

Target audience: you know perception. You don't need to write GLSL. You need to understand it enough to review a shader, critique its mappings, and talk about it with engineers.

---

## The core idea in one sentence

> **A fragment shader is a tiny program that runs independently for every pixel on screen, every frame.**

That's it. That's the whole model. You write a function. The GPU runs it a few million times per frame. Each run computes the colour of one pixel.

---

## The 30-second mental model

Imagine you have a 1920×1080 screen — about 2 million pixels. Every 1/60th of a second, you need to decide what colour each pixel is.

Writing 2 million `if` statements is obviously impossible. Instead, you write **one function** — the fragment shader. The GPU runs this function once per pixel, in parallel, with different *inputs*:

- The pixel's position on screen (normalised to 0–1)
- A clock (time since start)
- Any additional "knobs" you want to expose — these are called **uniforms**

The output is always the same: the colour of *this* pixel, *right now*.

```glsl
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;  // pixel position, 0–1
    float brightness = sin(iTime);          // uses the clock
    fragColor = vec4(brightness, brightness, brightness, 1.0);  // grey, pulsing
}
```

That's a complete fragment shader. It produces a screen that pulses from black to white to black. No frames. No timeline. Just: *"given this pixel position and this time, what colour?"*

---

## Uniforms: the input knobs

A **uniform** is a value that is the same across all pixels in a single frame but can change between frames.

```glsl
uniform float brightness;   // a single float, 0–1
uniform vec3 tint;          // three floats: red, green, blue
uniform float speed;        // how fast the pattern moves
```

Uniforms are how *external data* gets into the shader. For Chromaticity, **uniforms are where audio becomes visuals**:

- Kick drum hits → `brightness` uniform spikes
- Bassline energy → `tint.r` increases (redder)
- Tempo → `speed` goes up

The core product of Chromaticity is: *"for each uniform this shader exposes, which audio feature should drive it, and how?"* That's what the mapping profile (ADR-004) captures.

---

## Shadertoy: where the shaders come from

[Shadertoy](https://www.shadertoy.com/) is a community platform where artists share fragment shaders. Thousands of them exist. Most are visually stunning.

Almost none of them are audio-reactive. Why? Because wiring up audio-to-uniform mappings requires knowing both GLSL and audio DSP. Most shader artists are visual artists.

**Chromaticity's pitch**: you bring the shader, we handle the audio-reactive mapping. Artists keep their creative work; we add the music-responsiveness layer.

Shadertoy has a set of conventional uniforms that all shaders can use:
- `iTime` — time in seconds since start
- `iResolution` — screen size
- `iMouse` — cursor position
- `iChannel0`–`iChannel3` — input textures (including audio!)

The audio input is where Shadertoy traditionally added reactivity. But it's a texture, not semantic features. Chromaticity works at a higher level: it maps *meaningful* audio features (beat, spectral centroid, arousal) to the shader's *own* uniforms.

---

## What happens at every frame (60 times per second)

1. **Audio arrives** (or has just arrived from the microphone / line input)
2. **Features extracted**: energy, spectral centroid, beat detected? tempo?
3. **Mapping applied**: each audio feature drives one or more shader uniforms per the mapping profile
4. **GPU renders**: the shader runs once per pixel, using the new uniform values
5. **Frame displayed**

Total budget: ~16ms. Of that, audio features take ~1ms, mapping takes ~0.1ms, rendering takes ~5-10ms (depends on shader complexity). We have slack. The architecture keeps it that way (ADR-002).

---

## Why this matters for perception

Everything in the visual output is *literally* a mathematical function of the audio features. That means:

- If the mapping is wrong, the visuals misrepresent the music. "Wrong" here means **perceptually wrong** — the mapping violates what humans expect to see when they hear certain things.
- If the mapping is principled, the visuals reinforce perception. The bass feels *louder* because the visual is *bigger*. The high-hat feels *sharper* because the visual has *more high-frequency detail*.

The design question is not "what's a cool visual?" — the shader artists already answered that. The question is: **given this shader, what mapping of audio→uniforms produces perceptually coherent output?**

This is where perception science is load-bearing, not decorative.

---

## A concrete example

A shader has these user-defined uniforms:
```glsl
uniform float u_zoom;
uniform float u_color_shift;
uniform float u_detail;
uniform vec3  u_base_color;
```

For each, we need to answer:
1. **What does this uniform actually control?** (render-probe + source analysis — ADR-006)
2. **Which audio feature should drive it?** (CMC literature — Spence 2011, Palmer 2013)
3. **How should it be shaped?** (linear? log? step on beat?)

For `u_zoom`: probably controls spatial scale. Maps to `arousal` (high-energy sections feel close; ambient sections feel distant). Linear curve.

For `u_color_shift`: probably rotates the hue. Maps to `valence` (Palmer et al. 2013 — emotion mediates colour). Or to `spectral_centroid` (higher-frequency content = brighter). Needs context.

For `u_detail`: probably increases spatial frequency / texture complexity. Maps to `spectral_flux` (more overtone/noise content = more detail). Moderate evidence from timbre-texture CMC.

For `u_base_color`: colour is the hardest case. Individual variation is high (see ADR-004 colour_model). Best to pull from a user-selected palette modulated by valence.

**Every one of these mappings lives in the mapping profile as JSON with a `rationale` field.** Your job as a perceptual reviewer is to check whether the rationale holds. If not, propose a replacement — also in JSON.

---

## What you can skip

- **The actual GLSL syntax.** You don't need to write it. Fragment shaders look like C with some vector operations. An engineer can translate your perceptual intuition into code.
- **OpenGL/moderngl internals.** The rendering engine is our problem.
- **Shader optimisation.** If a shader is slow, that's an engineering issue.

## What you can't skip

- **Understanding what a uniform is.** It's the contract between audio and visuals. Every mapping decision is about a uniform.
- **Which audio features Chromaticity extracts.** The current feature vocabulary is in `docs/reference/audio-features.md` *(to be written, Phase 2)* — roughly: RMS energy, spectral centroid, spectral flux, onset events, tempo, beat pulse, sub-bass energy, arousal, valence.
- **The mapping schema.** See ADR-004. JSON, editable on GitHub, no code required.

---

## Further reading

- [Shadertoy](https://www.shadertoy.com/) — browse the ecosystem. Try the "Trending" page.
- [The Book of Shaders](https://thebookofshaders.com/) — best introduction if you ever do want to learn GLSL
- ADR-001 through ADR-006 — architectural decisions, written for engineers but readable
- `docs/reference/vocabulary.md` — shared glossary across perception, GLSL, and music

## Questions?

Open an issue with the `question` label. The glossary and this document will grow as real questions surface.
