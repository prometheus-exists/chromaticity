# Standards

## Language & Runtime
- Python 3.11+ (uv-managed, see pyproject.toml)
- GLSL (Shadertoy-compatible dialect, ES 3.0 target)

## Code Style
- Black formatter, 88-char line length
- Ruff for linting
- Type hints throughout
- Docstrings on all public functions

## Dependencies
- Declare in `pyproject.toml`, lock with `uv.lock`
- No unpinned dependencies in production code
- Prefer stdlib over third-party where equivalent

## Platform
- **macOS + Windows are co-primary targets** — every feature must work on both before it ships
- Cross-platform testing is a Definition of Done item, not an afterthought
- Platform-specific code paths (audio backends, shader dialects, file paths) must be documented + covered by CI on both OSes
- No Linux-specific code unless it's free (both Xavier's and Fletcher's dev environments are macOS/Windows)
- Line endings: use `.gitattributes` to enforce LF for source files (Windows dev must not introduce CRLF)

## Commits
- Conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`
- One logical change per commit
- No WIP commits to main

## Architecture
- Pre-processing and live runtime are strictly separated — nothing that belongs in pre-processing can run in the live loop
- Live loop latency budget: <5ms from audio capture to uniform injection
- All design decisions → ADR (see docs/ADR/)

## Testing
- Unit tests for audio analysis pipeline
- Render-probe results validated against known shaders
- No GUI popup tests (headless rendering only in CI)

## Accessibility & Safety
- **Photosensitive epilepsy**: audio-reactive flicker in the 3–30Hz range at high contrast can trigger seizures. Any visual output that could produce such flicker must be gated behind a user opt-in (default: photosensitive safe mode = ON)
- High-contrast strobe effects require an explicit warning at load time
- Flicker-rate limiter (Phase 2+): cap visual oscillation at 3Hz by default; user can opt out per-shader
- Follow W3C WCAG 2.3 guidelines (three flashes or fewer per second OR below the general flash threshold)

## Secrets
- No credentials, API keys, or tokens in the repo
- `.gitignore` covers common secret files
