# 0031 — RustFS console SSO via Authelia OIDC

- **Status**: Accepted
- **Date**: 2026-09-07
- **Deciders**: Diego

## Context

The RustFS console was published only on the LAN host
`rustfs-console.local.dynabase.nl`, so administering the object store from
outside the house needed an SSH port-forward. RustFS supports native OIDC
console login (the `1.0.0-alpha.94` binary carries the `RUSTFS_IDENTITY_OPENID_*`
env vars and the `/rustfs/admin/v3/oidc/callback/{provider_id}` route). As with
Grist (ADR 0018), forward-auth is not an option — Traefik is not in the tunnel
path — so authentication must live inside the app via native OIDC.

## Decision

Expose the RustFS console publicly at `rustfs-console.dynabase.nl` and require
**Authelia OIDC** login, reusing the ADR 0018 pattern. Access is gated by a new
Authelia authorization policy `rustfs_admins` (`group:admins` only), so `super`
(group `users`) is refused at the IdP. RustFS assigns every authenticated user
the built-in `consoleAdmin` policy via `RUSTFS_IDENTITY_OPENID_ROLE_POLICY`.
Root / access-key login stays enabled as break-glass. The console's LAN route is
removed (external-only); the S3 API routes are unchanged.

## Consequences

- `+` remote object-store administration with no SSH tunnel, using the same passkey login as Grist
- `+` config-as-code: the OIDC client, group gate, and RustFS settings all live in committed YAML (only the client secret is in SOPS)
- `+` reuses the existing Authelia IdP and the `traefik_cloudflare_companion` auto-DNS, so exposing the console needs no Cloudflare dashboard step
- `+` break-glass preserved — root/access-key console login still works if Authelia or the tunnel is down (reachable via SSH port-forward)
- `−` the RustFS console is now internet-facing; its security rests on the Authelia gate plus the admins-only policy
- `−` a new OIDC client secret to manage (SOPS + Authelia hash)
- `−` day-to-day admin login now depends on Authelia and the tunnel being up (hairpin token exchange, as in ADR 0018)
- `−` RustFS is alpha software and its OIDC support is relatively new; behaviour may change across image bumps

## Evidence

- `services/storage/docker-compose.yaml` — external console router + `RUSTFS_IDENTITY_OPENID_*` env
- `services/storage/secrets.enc.env` — `RUSTFS_IDENTITY_OPENID_CLIENT_SECRET` (SOPS)
- `services/security/authelia/configuration.yml` — `rustfs` OIDC client + `rustfs_admins` authorization policy
- (implementing PR/commit refs filled on merge)
