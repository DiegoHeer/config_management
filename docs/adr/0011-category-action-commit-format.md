# 0011 — `Category|Action:` commit format

- **Status**: Accepted
- **Date**: 2026-04-18
- **Deciders**: Diego

## Context

Git history needs to be scannable and automatable (for CHANGELOG generation).
Conventional Commits didn't fit the mental model (this isn't a library with a public API).
Ad-hoc messages provide no structure.

## Decision

Custom prefix `Category|Action: description`.
Categories: `Services`, `Ansible`, `Infrastructure`, `Config`.
Actions: `Add`, `Refactor`, `Remove`, `Fix`, `Update`, `Migrate`.

## Consequences

- `+` commits group by intent at a glance
- `+` git-cliff parser maps Actions to Keep-a-Changelog sections
- `−` non-standard; contributors need to learn it
- `−` git-cliff parser is custom (vs. release-please + conventional commits)

## Evidence

- `CLAUDE.md` — "Git commit format" section codifies the rule
- `cliff.toml` — `commit_parsers` implement the mapping
