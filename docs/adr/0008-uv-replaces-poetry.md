# 0008 — uv replacing Poetry for Python deps

- **Status**: Accepted
- **Date**: 2026-04-18
- **Deciders**: Diego

## Context

Ansible + Molecule + yamllint/ansible-lint etc. are all Python.
Poetry was the initial choice.
uv emerged as faster, simpler (single binary, no virtualenv management required).

## Decision

Migrate from Poetry to uv.
`pyproject.toml` stays; `poetry.lock` replaced by `uv.lock`.

## Consequences

- `+` dramatically faster installs
- `+` `uv run` replaces `poetry run` with identical ergonomics
- `−` uv is newer, smaller ecosystem, contributors may need intro

## Evidence

- `7a6e6cd` (2026-03-08) — migration commit
- `pyproject.toml`, `uv.lock`
