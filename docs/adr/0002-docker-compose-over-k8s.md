# 0002 — Docker Compose over Kubernetes

- **Status**: Accepted
- **Date**: 2026-04-18
- **Deciders**: Diego

## Context

Single home server, ~54 services, solo operator.
K8s (K3s/Talos/plain) would add operational burden (controllers, CNI, operators, backup of etcd) without a clear return at this scale.

## Decision

Stay on Docker Compose.
All services defined as Compose stacks grouped by category under `services/<category>/`.

## Consequences

- `+` single config surface; ops complexity bounded
- `+` no control plane to maintain, no cluster upgrades
- `−` no orchestration primitives (HA, autoscaling, self-healing across nodes) — see ADR 0003
- `−` can't reuse the K8s ecosystem (operators, Helm charts) for services

## Evidence

- `4abb69d` (2025-02-12) — initial Compose network
- `services/` — entire tree, 12 categories of Compose stacks
