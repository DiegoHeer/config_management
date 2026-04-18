# 0013 — External `home_server_network` Docker network

- **Status**: Accepted
- **Date**: 2026-04-18
- **Deciders**: Diego

## Context

Each Compose project creates its own default network; cross-stack routing (Traefik → service in another stack, cloudflared → Traefik) requires shared networking.
Options: explicit shared `external: true` network, or stack-per-compose with Traefik using socket discovery.

## Decision

A single Docker bridge network `home_server_network` declared `external: true` in every compose file.
Created by Ansible bootstrap.

## Consequences

- `+` Traefik, cloudflared, and any reverse-dependency stack can route to any service by container name
- `+` adding a new stack = attach to network + declare Traefik label; no per-stack wiring
- `−` flatter security boundary: all containers can reach each other (no inter-stack isolation)

## Evidence

- `4abb69d` (2025-02-12) — network created
- Every `services/**/docker-compose.yaml` declares `networks: [home_server_network]` external
