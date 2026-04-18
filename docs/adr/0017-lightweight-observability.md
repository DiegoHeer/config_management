# 0017 — Lightweight observability over Prometheus stack

- **Status**: Accepted
- **Date**: 2026-04-18
- **Deciders**: Diego

## Context

Peers (khuedoan, onedr0p, ahinko) ship full Prometheus + Grafana + Loki + Alloy.
That's ~4 services to learn, store, back up, alert on.
For a single-host ~54-service homelab, the observability-to-usefulness ratio is low.

## Decision

Deliberately scope observability to lightweight tools: Beszel (host + agent) for metrics/uptime; Dozzle for log tailing; Portracker for open ports.
Revisit if a real alerting need appears.

## Consequences

- `+` small memory footprint vs. gigabytes for the full stack
- `+` zero learning curve
- `−` no historical metrics beyond Beszel's window; no log retention across container restarts
- `−` no alert routing (email/ntfy on metric breach)

## Evidence

- `services/monitoring/docker-compose.yaml`
- Absence of Prom/Grafana/Loki anywhere in the repo
