# Traefik Migration Design

## Context

The home server infrastructure uses Ansible and Docker Compose for fully declarative configuration — except for reverse proxy routing. Nginx Proxy Manager (NPM) requires manual configuration through its web UI, making it the only component whose state isn't captured in code. This migration replaces NPM with Traefik to bring reverse proxy configuration into the same IaC workflow as everything else.

## Goals

- All reverse proxy routing defined declaratively in Docker Compose files via Traefik labels
- Automatic SSL via Let's Encrypt wildcard certificate with Cloudflare DNS challenge
- Minimal disruption to existing service architecture (network, volumes, Ansible roles)
- Full git-trackable proxy configuration

## Architecture

### Traefik Core

Traefik replaces NPM in `services/networking/docker-compose.yaml`.

**Entrypoints:**
- `web` — port 80 (HTTP), global redirect to HTTPS
- `websecure` — port 443 (HTTPS)

**Providers:**
- **Docker provider** — watches the Docker socket on `home_server_network`, discovers services via labels. `exposedByDefault: false` so services must opt-in with `traefik.enable=true`.
- **File provider** — watches `services/networking/traefik/dynamic/` directory for edge-case services that can't use Docker labels (host-networked containers).

**SSL/TLS:**
- Single wildcard certificate (`*.yourdomain.com`) via Let's Encrypt ACME
- DNS challenge using Cloudflare API (requires `CF_DNS_API_TOKEN` env var)
- Certificate stored in `acme.json`, volume-mounted for persistence
- Automatic renewal handled by Traefik

**Dashboard:**
- Traefik's built-in read-only dashboard, accessible at `traefik.yourdomain.com`
- Secured behind Traefik itself (routed via labels)

### Service Label Pattern

Each proxied service gets a standard set of labels in its `docker-compose.yaml`:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.<service>.rule=Host(`<service>.yourdomain.com`)"
  - "traefik.http.routers.<service>.entrypoints=websecure"
  - "traefik.http.routers.<service>.tls=true"
  - "traefik.http.services.<service>.loadbalancer.server.port=<container_port>"
```

The wildcard cert covers all subdomains automatically — individual services only need `tls=true`.

### Routing Categories

**Standard services (Docker labels):**
All services on `home_server_network` that are not host-networked or VPN-routed. This covers the vast majority (~45+ containers across dashboards, media, monitoring, storage, photos, security, tools, backups, games).

**VPN-routed services (labels on Gluetun):**
Services using `network_mode: service:gluetun` (qBittorrent, Prowlarr, Sonarr, Radarr, SABnzbd) share Gluetun's network stack. Traefik labels for these services go on the **Gluetun container** in `services/media/docker-compose.yaml`, with each service having its own router/service definition targeting the correct internal port.

Example for qBittorrent via Gluetun:
```yaml
services:
  gluetun:
    # ... existing config ...
    labels:
      - "traefik.enable=true"
      # qBittorrent
      - "traefik.http.routers.qbittorrent.rule=Host(`qbittorrent.yourdomain.com`)"
      - "traefik.http.routers.qbittorrent.entrypoints=websecure"
      - "traefik.http.routers.qbittorrent.tls=true"
      - "traefik.http.services.qbittorrent.loadbalancer.server.port=8080"
      # Prowlarr
      - "traefik.http.routers.prowlarr.rule=Host(`prowlarr.yourdomain.com`)"
      - "traefik.http.routers.prowlarr.entrypoints=websecure"
      - "traefik.http.routers.prowlarr.tls=true"
      - "traefik.http.services.prowlarr.loadbalancer.server.port=9696"
      # ... etc for sonarr, radarr, sabnzbd
```

**Host-networked services (file provider):**
Services with `network_mode: host` can't be discovered via Docker labels for routing. Only **Home Assistant** (port 8123) needs proxying among these. The others (OTBR, Matter Server, Doorbell Samba, Beszel Agent) are IoT/internal protocols that don't need HTTP reverse proxying.

File provider config at `services/networking/traefik/dynamic/home-assistant.yaml`:
```yaml
http:
  routers:
    homeassistant:
      rule: "Host(`ha.yourdomain.com`)"
      entryPoints:
        - websecure
      tls: {}
      service: homeassistant
  services:
    homeassistant:
      loadBalancer:
        servers:
          - url: "http://<HOST_IP>:8123"
```

**Services that don't need proxying:**
- Database containers (MariaDB, PostgreSQL, Redis) — internal only
- Immich ML — internal worker
- Beszel Agent — host-networked monitoring agent
- IoT services (OTBR, Matter Server) — non-HTTP protocols
- Doorbell Samba — SMB protocol

### Traefik Docker Compose Definition

Replaces NPM in `services/networking/docker-compose.yaml`:

```yaml
services:
  traefik:
    image: traefik:<pin-specific-version-at-implementation>
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik/acme:/acme
      - ./traefik/dynamic:/dynamic
    environment:
      - CF_DNS_API_TOKEN=${CF_DNS_API_TOKEN}
    command:
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=home_server_network"
      - "--providers.file.directory=/dynamic"
      - "--providers.file.watch=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.cloudflare.acme.dnschallenge=true"
      - "--certificatesresolvers.cloudflare.acme.dnschallenge.provider=cloudflare"
      - "--certificatesresolvers.cloudflare.acme.dnschallenge.resolvers=1.1.1.1:53,8.8.8.8:53"
      - "--certificatesresolvers.cloudflare.acme.email=${ACME_EMAIL}"
      - "--certificatesresolvers.cloudflare.acme.storage=/acme/acme.json"
    labels:
      - "traefik.enable=true"
      # Dashboard
      - "traefik.http.routers.dashboard.rule=Host(`traefik.yourdomain.com`)"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.tls=true"
      - "traefik.http.routers.dashboard.service=api@internal"
      # Wildcard cert
      - "traefik.http.routers.wildcard.tls.certresolver=cloudflare"
      - "traefik.http.routers.wildcard.tls.domains[0].main=yourdomain.com"
      - "traefik.http.routers.wildcard.tls.domains[0].sans=*.yourdomain.com"
    healthcheck:
      test: ["CMD", "traefik", "healthcheck"]
      interval: 30s
      timeout: 10s
      retries: 3
    mem_limit: 256m
```

## Changes to Existing Infrastructure

### Files Modified

- `services/networking/docker-compose.yaml` — Replace NPM with Traefik
- `services/dashboards/docker-compose.yaml` — Add labels to Homarr, Glance, Dashdot, Homepage
- `services/media/docker-compose.yaml` — Add labels to Jellyfin, Seerr, Navidrome, Audiobookshelf, Booklore; VPN labels on Gluetun
- `services/monitoring/docker-compose.yaml` — Add labels to Beszel, Dozzle, Portracker
- `services/storage/docker-compose.yaml` — Add labels to Filebrowser, Nextcloud
- `services/photos/docker-compose.yaml` — Add labels to Immich Server
- `services/security/docker-compose.yaml` — Add labels to Frigate (web UI on port 5000; streaming ports 8554/8555 remain directly exposed)
- `services/tools/docker-compose.yaml` — Add labels to IT-Tools, BentoPDF, Grist, Docuseal, Changedetection, Tandoor
- `services/backups/docker-compose.yaml` — Add labels to Zerobyte (port 4096) and Databasus (port 4005)
- `services/games/docker-compose.yaml` — Add labels to RomM
- `services/home_assistant/docker-compose.yaml` — No label changes (HA uses file provider)

### Files Added

- `services/networking/traefik/dynamic/home-assistant.yaml` — File provider route for HA

### Files Removed (after migration)

- NPM volume data can be cleaned up on the server (`./nginx-proxy-manager/`)

### Ansible Vault Changes

- Add `CF_DNS_API_TOKEN` to `vault_services_env.networking` (Cloudflare API token for DNS challenge)
- Add `ACME_EMAIL` to `vault_services_env.networking` (Let's Encrypt registration email)
- Remove any NPM-specific env vars if they exist

### What Stays Unchanged

- `home_server_network` external bridge network
- Cloudflare Tunnel service and configuration
- All service container configurations (images, volumes, ports, health checks)
- Ansible roles and task structure
- Network creation task in `roles/services/tasks/network.yml`

## Verification

1. **Traefik starts successfully**: `docker logs traefik` shows no errors, dashboard accessible at `traefik.yourdomain.com`
2. **Wildcard cert issued**: Check `acme.json` for valid cert, or visit any service subdomain and inspect the certificate
3. **Service routing works**: For each service category, verify at least one service is accessible via its subdomain with valid HTTPS
4. **VPN-routed services**: Confirm qBittorrent and *arr services are accessible through their subdomains while still routing traffic through Gluetun
5. **Home Assistant**: Verify file provider route works for `ha.yourdomain.com`
6. **HTTP redirect**: Confirm `http://anyservice.yourdomain.com` redirects to HTTPS
7. **Ansible deployment**: Run `uv run ansible-playbook playbooks/update_home_server.yml` and verify Traefik comes up correctly with all routes
