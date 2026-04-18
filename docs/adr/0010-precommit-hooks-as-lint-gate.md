# 0010 — Pre-commit hooks as local lint gate

- **Status**: Accepted
- **Date**: 2026-04-18
- **Deciders**: Diego

## Context

Lint failures caught only in CI waste PR cycles.
Wanted fail-fast feedback at commit time.

## Decision

Adopt `pre-commit` with yamllint, ansible-lint, ruff, shellcheck, actionlint, gitleaks, end-of-file-fixer, trim-trailing-whitespace, detect-private-key.

## Consequences

- `+` no broken commit lands in a PR
- `+` `gitleaks` catches accidental secrets before push
- `−` first-time setup needed per contributor (`pre-commit install`)

## Evidence

- `d349dfa` (2026-04-13) — pre-commit introduced
- `.pre-commit-config.yaml`
