# 0009 — Molecule for Ansible role testing

- **Status**: Accepted
- **Date**: 2026-04-18
- **Deciders**: Diego

## Context

Four Ansible roles (`system`, `projects`, `docker_host`, `restore`).
Changes historically broke things silently.
Needed a way to verify role idempotence + correctness in isolation.

## Decision

Use Ansible Molecule with the Docker driver.
One scenario per role.
Run in CI as a matrix job on pushes to `main` (skipped on PRs for speed).

## Consequences

- `+` roles are provably idempotent on every run
- `+` CI matrix surfaces regressions before Ansible touches the real host
- `−` Molecule's Docker driver doesn't match production (Ubuntu/bare-metal)
- `−` runtime: 2-5 min per scenario

## Evidence

- `03daf14` (2025-02-16) — Molecule introduced
- `molecule/` — 4 scenarios
- `.github/workflows/quality-check.yml`
