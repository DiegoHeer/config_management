# 0003 — Single-host homelab, no HA

- **Status**: Accepted
- **Date**: 2026-04-18
- **Deciders**: Diego

## Context

Peers (khuedoan, onedr0p, ahinko) run multi-node clusters with distributed storage (Rook/Ceph).
That implies redundant hardware and heavy ops overhead.
Household workload fits one server.

## Decision

One physical host.
No HA.
Outages during maintenance are acceptable.

## Consequences

- `+` hardware cost and ops burden minimized
- `+` Compose fits naturally (see ADR 0002)
- `−` hardware failure = full outage until restore (see ADR 0015)
- `−` no rolling upgrades for services; downtime during redeploys

## Evidence

- `README.md` — scope documented as "Personal homelab"
- Absence of any multi-host infrastructure in the repo
