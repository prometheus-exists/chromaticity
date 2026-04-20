# Security Policy

## Dependency Integrity

All production dependencies are pinned with SHA-256 hashes in `requirements.lock`.

**Reproducible install (recommended):**
```bash
uv pip install --require-hashes -r requirements.lock
```

This verifies every package against its expected hash and will refuse to install if any package has been tampered with. Never install from `pyproject.toml` alone in production or CI — use the lockfile.

**Updating dependencies:**
```bash
uv pip compile pyproject.toml --generate-hashes --upgrade --output-file requirements.lock
uv pip compile pyproject.toml --extra dev --generate-hashes --upgrade --output-file requirements-dev.lock
# Review the diff, test, then commit both files together
```

## Shader Sandboxing

Loaded shaders run inside a subprocess with restricted permissions (ADR-005). Do not load shaders from untrusted sources in live performance mode without reviewing them first.

## Reporting Vulnerabilities

This is a research project. If you find a security issue, open a GitHub issue marked `[SECURITY]` or contact the maintainers directly.
