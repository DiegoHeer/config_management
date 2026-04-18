# 0016 — Tailscale for CI → homelab access

- **Status**: Accepted
- **Date**: 2026-04-18
- **Deciders**: Diego

## Context

CI must reach the homelab to run Ansible.
Options: expose SSH on a public IP + firewall allow-list (fragile, requires static IP or DynDNS), site-to-site VPN, or Tailscale.
Cloudflare Tunnel (ADR 0007) is ingress-only.

## Decision

Tailscale with OAuth client credentials in GitHub secrets.
CI runs `tailscale up`, reaches the home server at its tailnet IP, runs Ansible over SSH.

## Consequences

- `+` zero public ports; the tailnet is the network
- `+` OAuth credentials are scoped (ephemeral nodes, tag-based ACLs)
- `−` dependency on Tailscale control plane
- `−` ephemeral tailnet nodes need auto-expire tags

## Evidence

- `.github/actions/setup-ansible/action.yml` — Tailscale up step
- GitHub secrets: `TAILSCALE_OAUTH_CLIENT_ID`, `TAILSCALE_OAUTH_CLIENT_SECRET`, `TAILSCALE_SERVER_IP`
