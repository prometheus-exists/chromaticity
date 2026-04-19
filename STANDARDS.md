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
- macOS primary (M-series), Windows supported
- No Linux-specific code unless it's free

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

## Secrets
- No credentials, API keys, or tokens in the repo
- `.gitignore` covers common secret files
