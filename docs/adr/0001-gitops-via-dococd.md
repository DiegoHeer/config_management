# 0001 — GitOps via DocoCD (push-based)

- **Status**: Accepted
- **Date**: 2026-04-18
- **Deciders**: Diego

## Context

Ansible-driven service deploys required a full playbook run per change — slow iteration, manual SSH.
Wanted reconciliation from git.
Rejected Flux/ArgoCD as K8s-bound and heavy for this scale.

## Decision

Adopt [DocoCD](https://github.com/kimdre/doco-cd) as the GitOps reconciler.
A `git push` to `main` triggers a webhook → DocoCD decrypts SOPS env → `docker compose up -d` per stack.

## Consequences

- `+` deploys are diffable in git; rollback = `git revert`
- `+` no per-change SSH; Ansible stays for bootstrap only (see ADR 0004)
- `−` push-based means every merge reaches production; mitigated by Renovate + CI
- `−` single DocoCD instance is a SPOF; Ansible bootstrap handles its recovery

## Evidence

- `9826eff` (2026-04-18) — Phase 0: DocoCD + SOPS bootstrap
- `6ef1d0b` (2026-04-18) — Phase 1 pilot: monitoring/ migrated
- `9e29a9a` (2026-04-18) — Final migration: media/
- `bootstrap/gitops/docker-compose.yaml` — DocoCD stack definition
