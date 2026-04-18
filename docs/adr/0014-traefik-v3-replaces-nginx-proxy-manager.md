# 0014 — Traefik v3 replacing Nginx Proxy Manager

- **Status**: Accepted
- **Date**: 2026-04-18
- **Deciders**: Diego

## Context

Early stack used Nginx Proxy Manager (NPM) — GUI-driven, stateful, proxy config in NPM's own database.
Couldn't be defined as-code, poor fit for GitOps.
Needed Let's Encrypt, wildcard via DNS challenge, internal DNS sync.

## Decision

Migrate to Traefik v3 with file-based configuration.
Routes defined via Docker labels on each service.
DNS challenge via Cloudflare API for wildcard cert.
Pi-hole DNS sync script keeps local DNS in step.

## Consequences

- `+` every route in git, labeled on the service that owns it
- `+` zero-config for new services (add the label set)
- `+` wildcard TLS via DNS challenge (no per-service HTTP challenge)
- `−` more complex mental model than NPM's GUI

## Evidence

- `4636583` (2026-03-29) — PR #5 merge: Traefik migration
- `57ec260` (2026-04-01) — file-based config + pihole DNS sync
- `services/networking/docker-compose.yaml`
