# Contributing to Chromaticity

Thanks for your interest. Chromaticity is a small, focused project — we want it to stay that way.

## Philosophy

- Live performance stability > features
- Perceptually principled > acoustically reactive
- Bring-your-own-shaders > marketplace
- Cross-platform (macOS + Windows) > single-OS optimisation
- Open > gated

If a proposed change violates these, the bar for acceptance is high.

## How to contribute

### Issues

Before opening an issue:
- Search existing issues — it may be tracked
- For bugs: include OS, Python version, `uv pip freeze` output, and repro steps
- For feature requests: explain the use case, not just the feature

### Pull Requests

1. **Fork and branch** — one feature/fix per PR
2. **Discuss first for non-trivial changes** — open an issue before a large PR
3. **Follow the standards** — see `docs/STANDARDS.md`
4. **Include tests** — new functionality requires tests; bugfixes require regression tests
5. **Update CHANGELOG.md** — add an entry under `[Unreleased]`
6. **Pass CI** — tests must pass on macOS + Windows; ruff lint clean; black formatted
7. **One ADR per architectural decision** — see `docs/reference/ADR/`

### Code standards

- Python 3.11+, type hints required on public APIs
- Black formatting, 88-char lines
- Ruff linting (includes `BLE001` — no bare `except Exception`)
- Docstrings on public functions
- Tests in `tests/` mirroring `src/` structure

See `docs/STANDARDS.md` for the full standard.

### Commits

Conventional Commits format:
```
<type>(<scope>): <subject>

<optional body>
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `style`.

## Architecture decisions

Significant decisions go in `docs/reference/ADR/` as ADR-NNN-slug.md files. Before proposing a major architectural change, read the existing ADRs to understand why things are the way they are.

Current ADRs:
- ADR-001: Render-probe for uniform semantic inference
- ADR-002: Pre-process / live runtime split

## Live performance safety

Any change that touches the live runtime path must not:
- Add network I/O
- Add inference in the critical path
- Introduce variable latency (jitter is worse than offset)
- Break on audio device hot-swap

Changes that could trigger seizures (rapid flicker 3-30 Hz, high-contrast strobe) require explicit documentation and user-facing warnings. Photosensitive epilepsy is a real safety issue, not optional.

## License

By contributing, you agree your contributions will be licensed under the MIT License (see `LICENSE`).

## Questions?

Open an issue with the `question` label, or reach out via the lab's Discord if you have access.
