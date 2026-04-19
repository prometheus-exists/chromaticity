# Shared Vocabulary

Chromaticity sits at the intersection of three fields that use the same words for different things. This glossary maps between them to prevent weeks of miscommunication.

**When in doubt**: say the field explicitly. "Perceptual brightness" vs "RGB brightness" vs "musical brightness" — three different things.

---

## `brightness`

| Field | Definition | How it's measured |
|-------|-----------|-------------------|
| **Perception science** | Subjective sensation of luminous intensity. Non-linear in physical light: doubling photons doesn't double perceived brightness. Formally: L* in CIE Lab space (0–100) — approximately a cube-root-scaled function of relative luminance, with a linear segment near black. Tuned to match human lightness discrimination. | Psychophysics (matching tasks); approximated by L* |
| **GLSL / graphics** | Often just `(r+g+b)/3` or max(r,g,b). Sometimes V in HSV, sometimes Y in YCbCr. **Not perceptually uniform** — naive RGB means doubling r/g/b values doesn't double perceived brightness. | `length(color.rgb)` or `dot(color.rgb, vec3(0.2126, 0.7152, 0.0722))` (ITU-R BT.709 luma) |
| **Music (timbre)** | Perceived sharpness/clarity of a sound. High "brightness" music has strong high-frequency energy. | Spectral centroid (the "centre of mass" of the spectrum, Hz) |

**Usage in Chromaticity**:
- When the spec says *"brightness CMC"*, it means **perceptual brightness** (L*).
- When render-probe measures *"luminance delta"*, it uses **GLSL-style luma** (fast, close-enough).
- When we map **musical brightness** (spectral centroid) → **visual brightness**, we mean **perceptual brightness** as the target, approximated via L*.

⚠️ The naive RGB approach will look wrong to a perception researcher. Phase 3 should use L*-based computation for the output colour model.

---

## `colour` / `color`

| Field | Definition | Representation |
|-------|-----------|----------------|
| **Perception science** | A subjective attribute of visual experience, described by hue, saturation, and lightness. Models: CIE XYZ, CIE Lab, opponent process (red-green, blue-yellow, black-white). | CIE Lab (perceptually uniform), CIE L\*u\*v\*, HSV (closer to perception than RGB but not perfect) |
| **GLSL / graphics** | `vec3` or `vec4` of floats in 0–1 range, typically linear RGB or sRGB. | `vec4(r, g, b, a)` |
| **Music** | "Tone colour" = **timbre**. The quality that distinguishes a clarinet from a violin at the same pitch and loudness. Multi-dimensional (brightness, roughness, attack sharpness, etc.). | MFCC, spectral shape features, perceptual timbre spaces (McAdams) |

**Usage in Chromaticity**:
- "Colour palette" means the visual palette the user selects (HSV or Lab, not RGB in the spec)
- "Tone colour" and "timbre" mean the same thing; we prefer **timbre** in technical specs to avoid confusion
- When render-probe says "this uniform affects colour", it means hue and/or saturation of GLSL output

---

## `tone`

| Field | Definition |
|-------|-----------|
| **Music** | Could mean: a single sustained pitch; a note's musical quality; the overall mood/character of a passage. Ambiguous — always ask. |
| **Perception** | Generally means auditory tone — a periodic sound with a pitch |
| **Graphics** | Often "tonal range" — the range of brightness values in an image |

**Usage in Chromaticity**: we avoid the bare word "tone" — use **pitch**, **timbre**, or **mood** explicitly.

---

## `pitch`

| Field | Definition |
|-------|-----------|
| **Music** | Perceptual correlate of fundamental frequency. Note names (C4, A440). |
| **Perception** | Subjective sensation of frequency. Non-linear — psychoacoustic scales (Mel, Bark) are more perceptually uniform than Hz. |
| **Graphics** | Not used. |

**Usage in Chromaticity**: always means musical/auditory pitch. For complex signals (DnB reese basses), **spectral centroid** often drives what sounds "higher pitched" better than F0 does.

---

## `frequency`

| Field | Definition |
|-------|-----------|
| **Audio DSP** | Cycles per second (Hz). Direct physical measurement. |
| **Perception** | Maps non-linearly to pitch. |
| **Graphics** | **Spatial frequency** — how fast the image changes across space. High spatial frequency = fine detail. Different from temporal frequency (flicker). |
| **Visual (temporal)** | Flicker rate — how fast the image changes over time. Critical for safety (3–30Hz is seizure-risk band). |

**Usage in Chromaticity**:
- "Audio frequency" → always Hz in a spectrum
- "Spatial frequency" → how detailed a shader's output is
- "Flicker rate" → how fast brightness changes over time (safety-critical per ADR-005)

---

## `intensity`

| Field | Definition |
|-------|-----------|
| **Audio** | Physical power of a sound (W/m²). Loudness is the perceptual correlate. |
| **Perception** | General word for magnitude of sensation. Often ambiguous. |
| **GLSL** | Often used generically for "how strong an effect is" — ambiguous, usually means amplitude or scaling factor. |

**Usage in Chromaticity**: avoid bare "intensity". Use **loudness**, **amplitude**, **RMS energy** (audio), or **magnitude** / **scale** (visual).

---

## `saturation`

| Field | Definition |
|-------|-----------|
| **Perception** | Colourfulness relative to brightness. Pure red is highly saturated; pastel pink is less saturated. |
| **GLSL (HSV)** | Second component of HSV. `s=0` → grey, `s=1` → pure hue. |
| **Audio (rare)** | Sometimes used metaphorically for distorted/overdriven signals. |

**Usage in Chromaticity**: always means **perceptual/HSV saturation** of visual output. Palmer 2013 — saturation maps to arousal (high-energy music → more saturated visuals).

---

## `groove`

| Field | Definition |
|-------|-----------|
| **Music psychology** | The compelling desire to move to music. Inverted-U relationship with syncopation (Witek 2014). |
| **Musicology** | Often used looser: "feel", "pocket", rhythmic character. |
| **Perception** | Not a standard perceptual term outside music. |

**Usage in Chromaticity**: the Witek 2014 operationalisation — medium syncopation produces maximum groove. If we ever claim a visualiser "enhances groove", this is what we mean and how we measure.

---

## `rhythm` vs `tempo` vs `beat` vs `pulse` vs `onset`

All closely related, often confused. Precise definitions:

| Term | Definition |
|------|-----------|
| **Onset** | The moment a new sound event begins. Every kick, snare, hihat has an onset. Detected with onset-detection algorithms (e.g. SuperFlux). |
| **Beat** | A perceived pulse at the primary metric level. A subset of onsets — the ones the listener taps to. |
| **Pulse** | Synonym for beat in most contexts. |
| **Tempo** | Rate of beats, in BPM. |
| **Rhythm** | The temporal pattern of onsets. "Rhythm" includes tempo + metric structure + syncopation. |
| **Metre** | The hierarchical grouping of beats (2/4, 4/4, 6/8). |

**Usage in Chromaticity**:
- **Onset** is what we detect from raw audio (low level)
- **Beat** is what we infer from the onset stream (requires tempo tracking)
- **Tempo** is the rate we estimate (autocorrelation over onsets)
- We don't attempt **metre** inference in Phase 1 — too hard without genre priors.

---

## `mapping`

| Context | Definition |
|---------|-----------|
| **Chromaticity spec** | The function from audio features to shader uniforms. Stored in `.mapping.json` per ADR-004. |
| **Perception science** | Cross-modal correspondence — a systematic association between features in different modalities (e.g. pitch ↔ height). |
| **Category theory** | A function between sets. If you see this in a research context, it means that. |

**Usage in Chromaticity**: always the first meaning — the data structure defining audio→uniform relationships.

---

## `flash rate` / `temporal luminance frequency`

| Field | Definition |
|-------|-----------|
| **Perception science** | Rate of luminance change that can trigger photosensitive seizures. Clinical danger zone: 3–30 Hz (Harding & Harding 1999). WCAG 2.3.1 sets the threshold at ≥3 general flashes/second or below the general-flash / red-flash thresholds. |
| **GLSL / graphics** | Frame-to-frame luminance delta. At 60fps, a brightness oscillation at N Hz means the luminance crosses its mean every 60/(2N) frames. |
| **Music** | Beat-synced brightness transients. At 174 BPM with 16th-note sync, brightness changes occur at ~11.6 Hz — mid-band of the danger zone. Even at 120 BPM, 16th notes produce ~8 Hz flicker. |

**Usage in Chromaticity**: the mapping engine enforces a maximum luminance-delta-per-frame constraint (see ADR-005). This is **not just a safety check, it's an accessibility feature**. Chromaticity can offer a photosensitivity-safe mode that limits temporal luminance changes while preserving the shader's aesthetic — something most visualiser software does not do. Framing: *"perceptually principled" includes "perceptually safe."*

---

## `arousal` vs `valence`

Core dimensions of the Russell circumplex model of affect (1980). Foundational for Palmer et al. 2013's music-colour finding.

| Term | Definition |
|------|-----------|
| **Arousal** | Low-to-high activation/intensity. Calm → excited. Mostly driven by energy, tempo. |
| **Valence** | Negative-to-positive affect. Sad → happy. Driven by mode (major/minor), harmonic brightness. |

**Usage in Chromaticity**: we extract approximate arousal and valence from audio features and use them to drive the colour model. Palmer et al. (2013) found that music-colour associations are mediated by shared emotional content — music and colours that evoke similar arousal/valence are perceived as "going together." Chromaticity's colour pipeline is built on this: music → emotion → colour, not music → colour directly.

---

## How to use this glossary

1. **When writing**: if a term has multi-field meanings, say the field ("perceptual brightness", "spectral brightness")
2. **When reviewing**: if a doc uses a bare term from the above list, check that the intended meaning is clear from context
3. **When onboarding someone new**: point them here first

This document is additive. If you encounter a term that causes confusion, add it.

Last updated: 2026-04-19
