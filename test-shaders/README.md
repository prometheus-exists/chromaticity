# Test Shader Suite — Phase 1 Render-Probe Spec

Selected by Fletcher Hammond, 2026-04-20. Five shaders covering distinct visual character types for render-probe analyser development and validation.

---

## Shader Inventory

### Dsf3WH — Sci-Fi HUD / Rings
**Type:** Geometric / mechanical UI  
**Visual character:** Concentric rotating rings with segment-display numerics, overlaid HUD elements (graphs, arrows, counters). Raymarched 3D — rings have actual Z-depth. Periodically shifts between angled 3D view and flat front-on (30s cycle).  
**Motion:** Multiple independent rotation speeds per ring; animated numeric readouts; scrolling background grid. Highly structured, clock-like.  
**Colour behaviour:** Monochrome white-on-black. Colour response entirely through luminance — no hue variation in the base shader.  
**Uniforms present:** `iTime`, `iResolution`, `iMouse`  
**Probe interest:** HIGH for temporal structure (iTime drives all motion). Good test case for how visual complexity / brightness responds to time-scaling. iMouse adds interactive angular control. Background grid is subtle — good for detecting uniform-driven brightness floor changes.  
**Complexity:** High — raymarcher + SDF geometry, 20KB of GLSL. Heaviest shader in the suite.

---

### ssjyWc — Fork Fragment
**Type:** Degenerate / minimal  
**Visual character:** This appears to be an incomplete or corrupted fork — the GLSL body is essentially empty (`Main Q = B(U).zzzz;`). Not renderable as-is.  
**Motion:** N/A  
**Colour behaviour:** N/A  
**Uniforms present:** Unknown  
**Probe interest:** SKIP for Phase 1. Flag for Fletcher — may need replacing with a working shader.  
**Action required:** Fletcher to verify or swap out.

---

### 7cBSDR — Voxel Reflection Tunnel (FabriceNeyret2 "-40")
**Type:** Abstract / psychedelic tunnel  
**Visual character:** Raymarched spherical inversion + voxel rounding + reflection produces a dense, shifting tunnel effect. Extremely compact (fits in ~15 lines). The `sin(iTime*.05 + vec3(3,2,0))` term slowly rotates the reflection axis — gives a slow morphing quality.  
**Motion:** Slow drift/morph with fast internal structure. Camera moves through the scene via `t` accumulation.  
**Colour behaviour:** Rich — `abs(sin(p.z*.5 - iTime + vec4(0,.2,.4,0)))` produces cycling colour bands tied to depth AND time. Highly responsive to iTime manipulation. Warm/cool oscillation.  
**Uniforms present:** `iTime`, `iResolution`  
**Probe interest:** HIGH for colour response. The colour is almost entirely driven by `iTime` — time-scaling will have dramatic effect on hue cycling rate. Excellent test case for the relationship between temporal uniformscaling and perceived colour velocity. Good candidate for the "emotional velocity" hypothesis.

---

### 3sySRK — Metaballs (smooth union SDF)
**Type:** Organic / fluid  
**Visual character:** 16 smoothly-blended spheres orbiting on sine-wave paths with randomised frequencies. Classic metaball look — blobs merge and separate. Normals computed analytically.  
**Motion:** Chaotic but structured — each sphere has independent random-seeded trajectory. Merges/separations happen continuously. Medium tempo feel.  
**Colour behaviour:** `cos((b + iTime*3.0) + uv.xyx*2.0 + vec3(0,2,4))` — hue cycles with time AND screen position AND lighting angle. Very responsive. Full RGB spectrum traversal.  
**Uniforms present:** `iTime`, `iResolution`  
**Probe interest:** HIGH for both motion and colour. The `iTime*3.0` multiplier makes colour cycling fast — good test of whether render-probe can detect colour velocity independently of motion velocity. Depth-based dimming (`exp(-depth*0.15)`) adds spatial dimensionality. Smooth, organic motion — the "emotional" feel is very different from Dsf3WH.

---

### sc2XDR — God Rays / Light Scattering (post-process)
**Type:** Atmospheric / volumetric  
**Visual character:** Post-process god-ray shader — reads from `iChannel0` (requires Buffer A with the actual scene), applies radial light-scattering blur toward a moving light source `vec3(cos(iTime), sin(iTime/1.4), 1e1)`. The light source orbits slowly.  
**Motion:** Light source moves on a ~6s period. The scattering creates directional streaks that shift as the source moves.  
**Colour behaviour:** Driven by underlying channel content + `sqrt(smoothstep(...))` tone mapping. Colour is inherited from iChannel0 — the god-ray effect tints/brightens. Warm when light is centred, cooler at edges.  
**Uniforms present:** `iTime`, `iResolution`, `iChannel0`  
**Probe interest:** MEDIUM — depends on what's in iChannel0. As a standalone it renders against a black texture, showing only the scattering pattern. More interesting once paired with another shader in the channel slot. Good test case for multi-pass dependency handling in the probe pipeline.  
**Note:** Requires iChannel0 — probe will need to handle this (either pass a test texture or detect the dependency and flag it).

---

## Coverage Assessment

| Dimension | Coverage |
|---|---|
| Geometric / structured | ✅ Dsf3WH |
| Organic / fluid | ✅ 3sySRK |
| Abstract / psychedelic | ✅ 7cBSDR |
| Atmospheric / post-process | ✅ sc2XDR |
| Degenerate / broken | ⚠️ ssjyWc (needs replacement) |
| Colour-dominant | ✅ 7cBSDR, 3sySRK |
| Motion-dominant | ✅ Dsf3WH |
| Multi-pass dependency | ✅ sc2XDR |
| Interactive (iMouse) | ✅ Dsf3WH |

**Recommendation:** Replace ssjyWc with a working shader. Good candidates: anything colour-heavy and relatively simple (2–3 uniforms) to complement the complexity of Dsf3WH. A pure 2D noise/gradient shader would round out the suite nicely.

## Phase 1 Probe Priority Order

1. **3sySRK** — clean uniforms, rich colour response, no dependencies
2. **7cBSDR** — extreme colour sensitivity to iTime, good hypothesis test
3. **Dsf3WH** — complex but reveals brightness/temporal structure response
4. **sc2XDR** — needs iChannel0 handling, tackle after single-pass probing works
5. **ssjyWc** — skip until replaced
