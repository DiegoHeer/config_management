# 0006 — Ansible Vault for bootstrap secrets

- **Status**: Accepted
- **Date**: 2026-04-18
- **Deciders**: Diego

## Context

Some secrets must exist BEFORE SOPS works: the age private key itself, the Cloudflared tunnel token, the user password.
These can't live in SOPS (bootstrap recursion).

## Decision

Use Ansible Vault for pre-DocoCD secrets.
Stored at `roles/*/vars/main/vault.yml`.
Decrypted by playbook using `VAULT_PASSWORD` from CI secret or local prompt.

## Consequences

- `+` two-tier model fits the two-tier lifecycle (one-time bootstrap, continuous runtime)
- `+` no external dependency before Docker is even installed
- `−` two secret stores, two rotation rituals to learn
- `−` vault password is itself a secret — lives in GitHub Actions secrets + local keychain

## Evidence

- `roles/docker_host/vars/main/env_vault.yml`
- `roles/system/vars/main/vault.yml`
