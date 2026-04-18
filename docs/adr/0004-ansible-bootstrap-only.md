# 0004 — Ansible reduced to bootstrap-only

- **Status**: Accepted
- **Date**: 2026-04-18
- **Deciders**: Diego

## Context

Early repo used Ansible for host setup AND per-service compose deploys.
After ADR 0001, DocoCD owns service deploys.
Ansible's service tasks became dead code.

## Decision

Limit Ansible to host bootstrap (Docker install, network, SOPS age key, Cloudflared token, DocoCD stack itself).
Rename the role `services` → `docker_host` to reflect the scope.

## Consequences

- `+` clear separation: one-time bootstrap vs. continuous reconciliation
- `+` playbook runs rare (only after host rebuild)
- `−` two config-management tools in the repo; contributors must know when each applies

## Evidence

- `1090e30` (2026-04-13) — deleted docker compose tasks from Ansible playbook
- `63899b5` (2026-04-18) — retire Ansible deploy tasks, consolidate gitops bootstrap
- `a00b7d7` (2026-04-18) — renamed `services` role to `docker_host`
