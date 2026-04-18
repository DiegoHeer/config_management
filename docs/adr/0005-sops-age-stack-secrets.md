# 0005 — SOPS + age for stack secrets

- **Status**: Accepted
- **Date**: 2026-04-18
- **Deciders**: Diego

## Context

Each stack needs env vars (DB passwords, API tokens).
Plaintext `.env` in git is unsafe.
Options: external vault (HashiCorp Vault, 1Password Connect), SOPS+age, SOPS+PGP, sealed-secrets (K8s-only).

## Decision

SOPS with age keys.
`.enc.env` files committed to git; the host has the matching age key planted by Ansible bootstrap.

## Consequences

- `+` encrypted secrets live in git; PR reviewer sees which keys changed
- `+` no external vault to run, secure, back up
- `+` asymmetric: anyone can add/update secrets with public key; only host decrypts
- `−` loss of the single age private key = all secrets unrecoverable (mitigated by ADR 0006)
- `−` Compose's `env_file` doesn't support `${VAR}` interpolation, so compose must include the final variable names directly

## Evidence

- `.sops.yaml` — age recipient config
- `9826eff` (2026-04-18) — SOPS bootstrap
- `services/**/*.enc.env` — the encrypted stack env files
