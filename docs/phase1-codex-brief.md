# Phase 1 Codex Brief — Render-Probe Uniform Analyser

## Project context

Chromaticity is a music-reactive GLSL shader visualiser. The render-probe is the offline pre-processing step that characterises each shader before live use. Given a GLSL shader, it sweeps `iTime` across a range, renders frames offscreen, and outputs a JSON profile describing how the shader's visual properties (luminance, colour, motion) respond to time.

**Read before coding:**
- `docs/reference/ADR/ADR-001-render-probe.md` — architecture decision
- `docs/explanation/design.md` — full design doc (if present)
- `TASKS.md` — open task list, Phase 1 item
- `pyproject.toml` — dependency list (moderngl, numpy, scikit-image needed for Phase 1)

## Deliverable

A working Python module: `chromaticity/probe.py` with a CLI entry point.

```
python -m chromaticity.probe --shader test-shaders/3sySRK.glsl --output profiles/3sySRK.json
python -m chromaticity.probe --shader test-shaders/negative_test.glsl --output profiles/negative_test.json
```

Phase 1 scope: **iTime sweep only**. No audio, no live path, no CMC mapping.

## Profile JSON schema

Every profile must conform to this schema. Define it as a dataclass or TypedDict in `chromaticity/profile.py`.

```json
{
  "schema_version": "1.0",
  "shader_id": "3sySRK",
  "shader_path": "test-shaders/3sySRK.glsl",
  "probe_date": "2026-04-20T19:00:00",
  "probe_config": {
    "resolution": [512, 512],
    "itime_start": 0.0,
    "itime_end": 60.0,
    "itime_step": 1.0,
    "warmup_frames": 0,
    "multi_pass": false,
    "feedback_loop": false
  },
  "itime_sensitivity": {
    "luminance": {
      "mean": [/* float per sample */],
      "std": 0.0,
      "range": [0.0, 1.0],
      "sensitivity_score": 0.0
    },
    "colour": {
      "mean_L": [/* CIELAB L* per sample */],
      "mean_a": [/* CIELAB a* per sample */],
      "mean_b": [/* CIELAB b* per sample */],
      "std_a": [/* std of a* per sample */],
      "std_b": [/* std of b* per sample */],
      "mean_chroma": [/* chroma = sqrt(a²+b²) per sample */],
      "colour_velocity": [/* |chroma[t] - chroma[t-1]| per step */],
      "sensitivity_score": 0.0
    },
    "motion": {
      "ssim_dissimilarity": [/* 1 - SSIM(frame_t, frame_{t-1}) per step */],
      "mean_dissimilarity": 0.0,
      "sensitivity_score": 0.0
    }
  },
  "uniforms_detected": ["iTime", "iResolution"],
  "flags": {
    "multi_pass": false,
    "feedback_loop": false,
    "needs_ichannel0": false,
    "compilation_error": null,
    "warmup_frames_used": 0,
    "sweep_complete": true,
    "possibly_incomplete": false
  }
}
```

`sensitivity_score` for each dimension: normalised 0–1, where 0 = no response (noise floor), 1 = maximum observed response across the test suite. Computed post-hoc once all shaders are profiled. For now, store the raw time series and compute sensitivity_score as `std(series) / mean(abs(series) + 1e-6)` as a placeholder.

## Architecture

### Module structure

```
chromaticity/
  __init__.py
  probe.py          # CLI entry point + orchestrator
  profile.py        # Profile dataclass + JSON serialisation
  renderer.py       # moderngl offscreen renderer, single-pass and multi-pass
  glsl_parser.py    # Static GLSL analysis — extract uniforms, detect multi-pass
  metrics.py        # Luminance, CIELAB colour distribution, SSIM dissimilarity
```

### glsl_parser.py

Static analysis only (regex + string parsing, no full GLSL parse):
- Extract all `uniform` declarations: name, type
- Classify Shadertoy builtins: `iTime`, `iResolution`, `iMouse`, `iChannel0`–`iChannel3`
- Detect `iChannel0` *reads* in the shader body → flag `needs_ichannel0`
- Detect self-referential feedback: if Buffer A reads `iChannel0` AND iChannel0 is wired to Buffer A's own output → flag `feedback_loop`
- Detect multi-pass: presence of multiple `mainImage` functions across provided pass files → flag `multi_pass`

**No runtime execution in parser** — pure text analysis.

### renderer.py

Offscreen moderngl renderer. Resolution: **512×512** (configurable).

**Single-pass shaders** (3sySRK, 7cBSDR, Dsf3WH, negative_test):
1. Compile and link the shader
2. For each iTime sample: set uniform, render to FBO, read pixels as numpy array (float32, RGBA)
3. Return list of frames

**Multi-pass, stateless** (sc2XDR: Buffer A → Image):
1. Create two FBOs: fbo_a (Buffer A output), fbo_image (final)
2. For each iTime sample:
   - Render Buffer A → fbo_a
   - Bind fbo_a as iChannel0 texture
   - Render Image → fbo_image
3. Read fbo_image pixels

**Multi-pass, feedback loop** (NddSWs: Buffer A reads its own previous output):
1. Create ping-pong FBO pair: fbo_a, fbo_b
2. Warmup phase: for N warmup frames, render Buffer A alternating fbo_a↔fbo_b, each reading the other as iChannel0. Hold iTime constant at the target sample value.
3. After warmup, read the final FBO as the measurement frame
4. Warm-start: carry the converged FBO state forward to the next iTime sample (don't reset to black)

**Warmup frames for feedback shaders:**
- Default: 100 frames warm-start (fast path)
- If `--cold-start` flag: 500 frames (slow, fully converged)
- Track convergence: if `|metric[n] - metric[n-1]| < 0.001` for 5 consecutive frames → converged early, stop

**Compilation gate:**
- If shader fails to compile, catch the exception, set `flags.compilation_error` to the error message, skip rendering, return profile with null metrics.
- Do NOT crash the whole probe run on a single shader failure.

**Timeout watchdog:**
- Each shader gets a 60-second wall-clock budget
- If exceeded: abort rendering, set `flags.sweep_complete = false`, write partial profile

### metrics.py

**Luminance:**
```python
# from RGBA float32 frame (values 0–1)
luminance = 0.2126 * frame[:,:,0] + 0.7152 * frame[:,:,1] + 0.0722 * frame[:,:,2]
mean_luminance = luminance.mean()
```

**CIELAB colour distribution:**
```python
# Convert RGB → CIELAB via skimage.color
from skimage.color import rgb2lab
lab = rgb2lab(frame[:,:,:3])  # shape (H, W, 3)
mean_L  = lab[:,:,0].mean()
mean_a  = lab[:,:,1].mean()
mean_b  = lab[:,:,2].mean()
std_a   = lab[:,:,1].std()
std_b   = lab[:,:,2].std()
mean_chroma = np.sqrt(lab[:,:,1]**2 + lab[:,:,2]**2).mean()
```

Do NOT use RGB centroid. Use CIELAB. This is non-negotiable — a mean of complementary RGB colours collapses to grey and destroys information.

**Motion (SSIM dissimilarity):**
```python
from skimage.metrics import structural_similarity as ssim
# Convert to greyscale float for SSIM
grey_t   = luminance_t    # already computed
grey_tm1 = luminance_tm1
score = ssim(grey_t, grey_tm1, data_range=1.0)
dissimilarity = 1.0 - score
```

No optical flow. SSIM dissimilarity is perceptually motivated and cheap. First frame has no previous frame — set dissimilarity = 0.0.

**Possibly-incomplete flag:**
After computing the luminance time series, compute autocorrelation. If the series shows no plateau or repeat within the sweep window, set `flags.possibly_incomplete = True`. Simple heuristic: if `std(series[-10:]) / (std(series) + 1e-6) > 0.5`, the series is still evolving at the end of the sweep.

## Test requirements

Create `tests/test_probe.py`:

1. **test_negative_case**: Run probe on `test-shaders/negative_test.glsl`. Assert `motion.mean_dissimilarity < 0.01` and `colour.sensitivity_score < 0.05`. This is the calibration test — it must pass for any other sensitivity measurements to be meaningful.

2. **test_compilation_gate**: Pass a deliberately broken GLSL string. Assert profile has `flags.compilation_error` set and metrics are null. Assert no exception raised.

3. **test_single_pass**: Run probe on `test-shaders/3sySRK.glsl`. Assert `motion.mean_dissimilarity > 0.01` (it IS time-sensitive). Assert `colour.std_a` or `colour.std_b` shows variation over the sweep (colour changes).

4. **test_profile_schema**: Load any output JSON and validate it contains all required top-level keys and that `schema_version == "1.0"`.

## Multi-pass shader metadata

Phase 1 requires manually specifying which files are which pass. CLI for multi-pass:

```
python -m chromaticity.probe \
  --shader-buffer-a test-shaders/sc2XDR_bufferA.glsl \
  --shader-image    test-shaders/sc2XDR.glsl \
  --output profiles/sc2XDR.json
```

For NddSWs (feedback):
```
python -m chromaticity.probe \
  --shader-buffer-a  test-shaders/NddSWs_bufferA.glsl \
  --shader-common    test-shaders/NddSWs_common.glsl \
  --shader-image     test-shaders/NddSWs.glsl \
  --feedback-loop \
  --output profiles/NddSWs.json
```

Auto-detection of multi-pass from a single file is Phase 2. For now, require explicit pass specification.

## What is explicitly NOT in Phase 1

- Audio input of any kind
- Live rendering path
- iMouse sweep (2D grid = expensive, different strategy needed)
- iResolution sweep
- Custom uniform discovery (no annotation format yet)
- Optical flow / motion direction
- Automatic periodicity detection
- CMC mapping application
- Any UX

## pyproject.toml additions needed

Add to dependencies:
```
"scikit-image>=0.22",   # MIT — SSIM + CIELAB conversion
```

## Definition of Done

Phase 1 is complete when:
- [ ] All 4 tests pass
- [ ] Probe produces valid schema-conformant JSON for: `negative_test`, `3sySRK`, `7cBSDR` (three single-pass shaders minimum)
- [ ] `negative_test` produces `motion.mean_dissimilarity < 0.01` (noise floor calibrated)
- [ ] `3sySRK` produces `colour.std_a > 0` across sweep (colour distribution captured)
- [ ] Profile JSON written to `profiles/` directory
- [ ] CHANGELOG.md updated with Phase 1 entry
- [ ] No GPL/AGPL/NC dependencies introduced

## Repo location

`/Users/prometheus/.openclaw/workspace/01-projects/products/chromaticity/`

Git user: `prometheus` / `prometheus.exists@icloud.com`
