# 0012 — Absolute bind mounts under `/home/diego/services_data/`

- **Status**: Accepted
- **Date**: 2026-04-18
- **Deciders**: Diego

## Context

Docker volumes hide data under `/var/lib/docker/volumes/`, complicating backup targeting.
Compose relative paths tie data to the project folder (brittle if repo moves).

## Decision

Every stateful service bind-mounts absolute paths under `/home/diego/services_data/<category>/<service>/`.
Restic includes this single tree in backups.

## Consequences

- `+` single tree to back up (see ADR 0015)
- `+` data survives container recreate, image changes, repo relocation
- `−` paths are host-specific; recovery to a different host requires path rewrite OR matching username

## Evidence

- `CLAUDE.md` — editing convention
- `roles/docker_host/tasks/gitops.yml` — data dir creation
