# Traefik Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Nginx Proxy Manager with Traefik for fully declarative reverse proxy configuration via Docker labels.

**Architecture:** Traefik runs in `services/networking/` with Docker provider (auto-discovers labeled services on `home_server_network`) and a file provider (for host-networked Home Assistant). All standard services get Traefik labels in their `docker-compose.yaml`. VPN-routed services get labels on the Gluetun container. Wildcard SSL via Let's Encrypt DNS challenge through Cloudflare.

**Tech Stack:** Traefik v3, Docker Compose, Let's Encrypt ACME, Cloudflare DNS API

---

## File Structure

**Modified files:**
- `services/networking/docker-compose.yaml` — Replace NPM with Traefik
- `services/dashboards/docker-compose.yaml` — Add labels to 4 services
- `services/media/docker-compose.yaml` — Add labels to 7 services + VPN labels on Gluetun
- `services/monitoring/docker-compose.yaml` — Add labels to 3 services
- `services/storage/docker-compose.yaml` — Add labels to 3 services
- `services/photos/docker-compose.yaml` — Add labels to Immich Server
- `services/security/docker-compose.yaml` — Add labels to Frigate
- `services/tools/docker-compose.yaml` — Add labels to 6 services
- `services/backups/docker-compose.yaml` — Add labels to 2 services
- `services/games/docker-compose.yaml` — Add labels to RomM

**New files:**
- `services/networking/traefik/dynamic/home-assistant.yaml` — File provider route for HA

**No changes needed for (internal/non-HTTP services):**
- Database containers (booklore_mariadb, nextcloud_mariadb, tandoor_postgres, romm_mariadb, immich_postgres)
- Internal workers (immich-machine-learning, redis)
- IoT/protocol services (mosquitto, openthread_border_router, matter_server, doorbell_samba)
- Monitoring agent (beszel-agent)
- Cloudflare tunnel (independent ingress path)

---

### Task 1: Replace NPM with Traefik in networking compose

**Files:**
- Modify: `services/networking/docker-compose.yaml`
- Create: `services/networking/traefik/dynamic/` (empty dir for file provider)

- [ ] **Step 1: Remove NPM service and add Traefik service**

Replace the full content of `services/networking/docker-compose.yaml` with:

```yaml
services:
  traefik:
    container_name: traefik
    image: traefik:v3.4
    restart: unless-stopped
    ports:
      - 80:80
      - 443:443
    environment:
      - CF_DNS_API_TOKEN=${CF_DNS_API_TOKEN}
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik/acme:/acme
      - ./traefik/dynamic:/dynamic
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
      - "traefik.http.routers.dashboard.rule=Host(`traefik.dynabase.nl`)"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.tls=true"
      - "traefik.http.routers.dashboard.tls.certresolver=cloudflare"
      - "traefik.http.routers.dashboard.tls.domains[0].main=dynabase.nl"
      - "traefik.http.routers.dashboard.tls.domains[0].sans=*.dynabase.nl"
      - "traefik.http.routers.dashboard.service=api@internal"
    healthcheck:
      test: ["CMD", "traefik", "healthcheck"]
      interval: 30s
      timeout: 10s
      retries: 3
    mem_limit: 256m

  cloudflare_tunnel:
    container_name: cloudflare_tunnel
    image: cloudflare/cloudflared:latest
    restart: unless-stopped
    command: tunnel --no-autoupdate run --token ${CLOUDFLARE_TOKEN}
    environment:
      TUNNEL_METRICS: "0.0.0.0:60123"
    healthcheck:
      test: ["CMD", "cloudflared", "tunnel", "ready"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s

networks:
  default:
    external: true
    name: home_server_network
```

- [ ] **Step 2: Create the dynamic config directory**

```bash
mkdir -p services/networking/traefik/acme services/networking/traefik/dynamic
```

- [ ] **Step 3: Validate YAML syntax**

```bash
uv run yamllint services/networking/docker-compose.yaml
```

Expected: no errors (may have warnings about line length for labels, which is acceptable)

- [ ] **Step 4: Commit**

```bash
git add services/networking/docker-compose.yaml services/networking/traefik/
git commit -m "Services|Refactor: replaced nginx proxy manager with traefik"
```

---

### Task 2: Add file provider route for Home Assistant

**Files:**
- Create: `services/networking/traefik/dynamic/home-assistant.yaml`

- [ ] **Step 1: Create the Home Assistant dynamic route file**

Create `services/networking/traefik/dynamic/home-assistant.yaml`:

```yaml
http:
  routers:
    homeassistant:
      rule: "Host(`ha.dynabase.nl`)"
      entryPoints:
        - websecure
      tls: {}
      service: homeassistant
  services:
    homeassistant:
      loadBalancer:
        servers:
          - url: "http://192.168.1.229:8123"
```

Note: The file provider does not support Docker Compose env var interpolation — values are hardcoded. Home Assistant runs with `network_mode: host` so it's accessible on the host's LAN IP (192.168.1.229).

- [ ] **Step 2: Validate YAML syntax**

```bash
uv run yamllint services/networking/traefik/dynamic/home-assistant.yaml
```

- [ ] **Step 3: Commit**

```bash
git add services/networking/traefik/dynamic/home-assistant.yaml
git commit -m "Services|Add: added traefik file provider route for home assistant"
```

---

### Task 3: Add Traefik labels to dashboards

**Files:**
- Modify: `services/dashboards/docker-compose.yaml`

- [ ] **Step 1: Add labels to all dashboard services**

Add these labels to each service in `services/dashboards/docker-compose.yaml`:

**homarr** (internal port 7575):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.homarr.rule=Host(`homarr.dynabase.nl`)"
      - "traefik.http.routers.homarr.entrypoints=websecure"
      - "traefik.http.routers.homarr.tls=true"
      - "traefik.http.services.homarr.loadbalancer.server.port=7575"
```

**glance** (internal port 8080):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.glance.rule=Host(`glance.dynabase.nl`)"
      - "traefik.http.routers.glance.entrypoints=websecure"
      - "traefik.http.routers.glance.tls=true"
      - "traefik.http.services.glance.loadbalancer.server.port=8080"
```

**dash** (internal port 3001):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dash.rule=Host(`dash.dynabase.nl`)"
      - "traefik.http.routers.dash.entrypoints=websecure"
      - "traefik.http.routers.dash.tls=true"
      - "traefik.http.services.dash.loadbalancer.server.port=3001"
```

**homepage** (internal port 3000):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.homepage.rule=Host(`homepage.dynabase.nl`)"
      - "traefik.http.routers.homepage.entrypoints=websecure"
      - "traefik.http.routers.homepage.tls=true"
      - "traefik.http.services.homepage.loadbalancer.server.port=3000"
```

- [ ] **Step 2: Validate YAML syntax**

```bash
uv run yamllint services/dashboards/docker-compose.yaml
```

- [ ] **Step 3: Commit**

```bash
git add services/dashboards/docker-compose.yaml
git commit -m "Services|Update: added traefik labels to dashboard services"
```

---

### Task 4: Add Traefik labels to media services

**Files:**
- Modify: `services/media/docker-compose.yaml`

This is the most complex file — standard services get their own labels, VPN-routed services get labels on Gluetun.

- [ ] **Step 1: Add labels to standard media services**

**jellyfin** (internal port 8096):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.jellyfin.rule=Host(`jellyfin.dynabase.nl`)"
      - "traefik.http.routers.jellyfin.entrypoints=websecure"
      - "traefik.http.routers.jellyfin.tls=true"
      - "traefik.http.services.jellyfin.loadbalancer.server.port=8096"
```

**seerr** (internal port 5055):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.seerr.rule=Host(`seerr.dynabase.nl`)"
      - "traefik.http.routers.seerr.entrypoints=websecure"
      - "traefik.http.routers.seerr.tls=true"
      - "traefik.http.services.seerr.loadbalancer.server.port=5055"
```

**profilarr** (internal port 6868):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.profilarr.rule=Host(`profilarr.dynabase.nl`)"
      - "traefik.http.routers.profilarr.entrypoints=websecure"
      - "traefik.http.routers.profilarr.tls=true"
      - "traefik.http.services.profilarr.loadbalancer.server.port=6868"
```

**navidrome** (internal port 4533):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.navidrome.rule=Host(`navidrome.dynabase.nl`)"
      - "traefik.http.routers.navidrome.entrypoints=websecure"
      - "traefik.http.routers.navidrome.tls=true"
      - "traefik.http.services.navidrome.loadbalancer.server.port=4533"
```

**audiobookshelf** (internal port 80):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.audiobookshelf.rule=Host(`audiobookshelf.dynabase.nl`)"
      - "traefik.http.routers.audiobookshelf.entrypoints=websecure"
      - "traefik.http.routers.audiobookshelf.tls=true"
      - "traefik.http.services.audiobookshelf.loadbalancer.server.port=80"
```

**booklore** (internal port 6060):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.booklore.rule=Host(`booklore.dynabase.nl`)"
      - "traefik.http.routers.booklore.entrypoints=websecure"
      - "traefik.http.routers.booklore.tls=true"
      - "traefik.http.services.booklore.loadbalancer.server.port=6060"
```

- [ ] **Step 2: Add VPN-routed service labels to Gluetun**

Add these labels to the `gluetun` service. Each VPN-routed service gets its own router and service definition:

```yaml
    labels:
      - "traefik.enable=true"
      # qBittorrent (port 8080)
      - "traefik.http.routers.qbittorrent.rule=Host(`qbittorrent.dynabase.nl`)"
      - "traefik.http.routers.qbittorrent.entrypoints=websecure"
      - "traefik.http.routers.qbittorrent.tls=true"
      - "traefik.http.services.qbittorrent.loadbalancer.server.port=8080"
      # Prowlarr (port 9696)
      - "traefik.http.routers.prowlarr.rule=Host(`prowlarr.dynabase.nl`)"
      - "traefik.http.routers.prowlarr.entrypoints=websecure"
      - "traefik.http.routers.prowlarr.tls=true"
      - "traefik.http.services.prowlarr.loadbalancer.server.port=9696"
      # Sonarr (port 8989)
      - "traefik.http.routers.sonarr.rule=Host(`sonarr.dynabase.nl`)"
      - "traefik.http.routers.sonarr.entrypoints=websecure"
      - "traefik.http.routers.sonarr.tls=true"
      - "traefik.http.services.sonarr.loadbalancer.server.port=8989"
      # Radarr (port 7878)
      - "traefik.http.routers.radarr.rule=Host(`radarr.dynabase.nl`)"
      - "traefik.http.routers.radarr.entrypoints=websecure"
      - "traefik.http.routers.radarr.tls=true"
      - "traefik.http.services.radarr.loadbalancer.server.port=7878"
      # SABnzbd (port 8085)
      - "traefik.http.routers.sabnzbd.rule=Host(`sabnzbd.dynabase.nl`)"
      - "traefik.http.routers.sabnzbd.entrypoints=websecure"
      - "traefik.http.routers.sabnzbd.tls=true"
      - "traefik.http.services.sabnzbd.loadbalancer.server.port=8085"
```

- [ ] **Step 3: Validate YAML syntax**

```bash
uv run yamllint services/media/docker-compose.yaml
```

- [ ] **Step 4: Commit**

```bash
git add services/media/docker-compose.yaml
git commit -m "Services|Update: added traefik labels to media services"
```

---

### Task 5: Add Traefik labels to monitoring services

**Files:**
- Modify: `services/monitoring/docker-compose.yaml`

- [ ] **Step 1: Add labels to monitoring services**

**beszel** (internal port 8090):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.beszel.rule=Host(`beszel.dynabase.nl`)"
      - "traefik.http.routers.beszel.entrypoints=websecure"
      - "traefik.http.routers.beszel.tls=true"
      - "traefik.http.services.beszel.loadbalancer.server.port=8090"
```

**dozzle** (internal port 8080):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dozzle.rule=Host(`dozzle.dynabase.nl`)"
      - "traefik.http.routers.dozzle.entrypoints=websecure"
      - "traefik.http.routers.dozzle.tls=true"
      - "traefik.http.services.dozzle.loadbalancer.server.port=8080"
```

**portracker** (internal port 4999):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portracker.rule=Host(`portracker.dynabase.nl`)"
      - "traefik.http.routers.portracker.entrypoints=websecure"
      - "traefik.http.routers.portracker.tls=true"
      - "traefik.http.services.portracker.loadbalancer.server.port=4999"
```

Skip `beszel-agent` — it uses `network_mode: host` and is a monitoring agent, not a web service.

- [ ] **Step 2: Validate YAML syntax**

```bash
uv run yamllint services/monitoring/docker-compose.yaml
```

- [ ] **Step 3: Commit**

```bash
git add services/monitoring/docker-compose.yaml
git commit -m "Services|Update: added traefik labels to monitoring services"
```

---

### Task 6: Add Traefik labels to storage services

**Files:**
- Modify: `services/storage/docker-compose.yaml`

- [ ] **Step 1: Add labels to storage services**

**filebrowser** (internal port 80):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.filebrowser.rule=Host(`filebrowser.dynabase.nl`)"
      - "traefik.http.routers.filebrowser.entrypoints=websecure"
      - "traefik.http.routers.filebrowser.tls=true"
      - "traefik.http.services.filebrowser.loadbalancer.server.port=80"
```

**nextcloud** (internal port 80):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.nextcloud.rule=Host(`nextcloud.dynabase.nl`)"
      - "traefik.http.routers.nextcloud.entrypoints=websecure"
      - "traefik.http.routers.nextcloud.tls=true"
      - "traefik.http.services.nextcloud.loadbalancer.server.port=80"
```

**obsidian-livesync** (internal port 5984):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.obsidian-livesync.rule=Host(`obsidian.dynabase.nl`)"
      - "traefik.http.routers.obsidian-livesync.entrypoints=websecure"
      - "traefik.http.routers.obsidian-livesync.tls=true"
      - "traefik.http.services.obsidian-livesync.loadbalancer.server.port=5984"
```

Skip `nextcloud_mariadb` — internal database.

- [ ] **Step 2: Validate YAML syntax**

```bash
uv run yamllint services/storage/docker-compose.yaml
```

- [ ] **Step 3: Commit**

```bash
git add services/storage/docker-compose.yaml
git commit -m "Services|Update: added traefik labels to storage services"
```

---

### Task 7: Add Traefik labels to photos services

**Files:**
- Modify: `services/photos/docker-compose.yaml`

- [ ] **Step 1: Add labels to Immich Server**

**immich-server** (internal port 2283):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.immich.rule=Host(`immich.dynabase.nl`)"
      - "traefik.http.routers.immich.entrypoints=websecure"
      - "traefik.http.routers.immich.tls=true"
      - "traefik.http.services.immich.loadbalancer.server.port=2283"
```

Skip `immich-machine-learning`, `redis`, `database` — internal services.

- [ ] **Step 2: Validate YAML syntax**

```bash
uv run yamllint services/photos/docker-compose.yaml
```

- [ ] **Step 3: Commit**

```bash
git add services/photos/docker-compose.yaml
git commit -m "Services|Update: added traefik labels to immich"
```

---

### Task 8: Add Traefik labels to security services

**Files:**
- Modify: `services/security/docker-compose.yaml`

- [ ] **Step 1: Add labels to Frigate**

**frigate** (internal port 5000 for web UI):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.frigate.rule=Host(`frigate.dynabase.nl`)"
      - "traefik.http.routers.frigate.entrypoints=websecure"
      - "traefik.http.routers.frigate.tls=true"
      - "traefik.http.services.frigate.loadbalancer.server.port=5000"
```

Note: Ports 8554 and 8555 (RTSP/WebRTC streaming) remain directly exposed via `ports:` — these are not HTTP and shouldn't go through Traefik.

- [ ] **Step 2: Validate YAML syntax**

```bash
uv run yamllint services/security/docker-compose.yaml
```

- [ ] **Step 3: Commit**

```bash
git add services/security/docker-compose.yaml
git commit -m "Services|Update: added traefik labels to frigate"
```

---

### Task 9: Add Traefik labels to tools services

**Files:**
- Modify: `services/tools/docker-compose.yaml`

- [ ] **Step 1: Add labels to all tool services**

**it-tools** (internal port 80):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.it-tools.rule=Host(`it-tools.dynabase.nl`)"
      - "traefik.http.routers.it-tools.entrypoints=websecure"
      - "traefik.http.routers.it-tools.tls=true"
      - "traefik.http.services.it-tools.loadbalancer.server.port=80"
```

**bentopdf** (internal port 8080):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.bentopdf.rule=Host(`bentopdf.dynabase.nl`)"
      - "traefik.http.routers.bentopdf.entrypoints=websecure"
      - "traefik.http.routers.bentopdf.tls=true"
      - "traefik.http.services.bentopdf.loadbalancer.server.port=8080"
```

**grist** (internal port 9999):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.grist.rule=Host(`grist.dynabase.nl`)"
      - "traefik.http.routers.grist.entrypoints=websecure"
      - "traefik.http.routers.grist.tls=true"
      - "traefik.http.services.grist.loadbalancer.server.port=9999"
```

**docuseal** (internal port 3000):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.docuseal.rule=Host(`docuseal.dynabase.nl`)"
      - "traefik.http.routers.docuseal.entrypoints=websecure"
      - "traefik.http.routers.docuseal.tls=true"
      - "traefik.http.services.docuseal.loadbalancer.server.port=3000"
```

**changedetection** (internal port 5000):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.changedetection.rule=Host(`changedetection.dynabase.nl`)"
      - "traefik.http.routers.changedetection.entrypoints=websecure"
      - "traefik.http.routers.changedetection.tls=true"
      - "traefik.http.services.changedetection.loadbalancer.server.port=5000"
```

**tandoor** (internal port 80):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.tandoor.rule=Host(`tandoor.dynabase.nl`)"
      - "traefik.http.routers.tandoor.entrypoints=websecure"
      - "traefik.http.routers.tandoor.tls=true"
      - "traefik.http.services.tandoor.loadbalancer.server.port=80"
```

Skip `tandoor_postgres` — internal database.

- [ ] **Step 2: Validate YAML syntax**

```bash
uv run yamllint services/tools/docker-compose.yaml
```

- [ ] **Step 3: Commit**

```bash
git add services/tools/docker-compose.yaml
git commit -m "Services|Update: added traefik labels to tool services"
```

---

### Task 10: Add Traefik labels to backup services

**Files:**
- Modify: `services/backups/docker-compose.yaml`

- [ ] **Step 1: Add labels to backup services**

**zerobyte** (internal port 4096):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.zerobyte.rule=Host(`zerobyte.dynabase.nl`)"
      - "traefik.http.routers.zerobyte.entrypoints=websecure"
      - "traefik.http.routers.zerobyte.tls=true"
      - "traefik.http.services.zerobyte.loadbalancer.server.port=4096"
```

**databasus** (internal port 4005):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.databasus.rule=Host(`databasus.dynabase.nl`)"
      - "traefik.http.routers.databasus.entrypoints=websecure"
      - "traefik.http.routers.databasus.tls=true"
      - "traefik.http.services.databasus.loadbalancer.server.port=4005"
```

- [ ] **Step 2: Validate YAML syntax**

```bash
uv run yamllint services/backups/docker-compose.yaml
```

- [ ] **Step 3: Commit**

```bash
git add services/backups/docker-compose.yaml
git commit -m "Services|Update: added traefik labels to backup services"
```

---

### Task 11: Add Traefik labels to games services

**Files:**
- Modify: `services/games/docker-compose.yaml`

- [ ] **Step 1: Add labels to RomM**

**romm** (internal port 8080):
```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.romm.rule=Host(`romm.dynabase.nl`)"
      - "traefik.http.routers.romm.entrypoints=websecure"
      - "traefik.http.routers.romm.tls=true"
      - "traefik.http.services.romm.loadbalancer.server.port=8080"
```

Skip `romm_mariadb` — internal database.

- [ ] **Step 2: Validate YAML syntax**

```bash
uv run yamllint services/games/docker-compose.yaml
```

- [ ] **Step 3: Commit**

```bash
git add services/games/docker-compose.yaml
git commit -m "Services|Update: added traefik labels to romm"
```

---

### Task 12: Update Ansible vault with new environment variables

**Files:**
- Modify: `roles/services/vars/main/env_vault.yml` (encrypted vault)

- [ ] **Step 1: Create a Cloudflare API token for DNS challenge**

1. Go to Cloudflare Dashboard > My Profile > API Tokens
2. Create Token > Edit zone DNS template
3. Permissions: Zone > DNS > Edit
4. Zone Resources: Include > Specific zone > dynabase.nl
5. Copy the token

- [ ] **Step 2: Add new env vars to the networking section of the vault**

```bash
uv run ansible-vault edit roles/services/vars/main/env_vault.yml --vault-password-file .vault_key
```

Add under `vault_services_env.networking`:
```yaml
vault_services_env:
  networking:
    CLOUDFLARE_TOKEN: "existing-value"
    CF_DNS_API_TOKEN: "your-new-cloudflare-dns-api-token"
    ACME_EMAIL: "your-email@example.com"
```

Note: Domain is hardcoded in labels, so no `DOMAIN` env var is needed.

- [ ] **Step 3: Remove NPM-specific env vars if present**

Check if there are any NPM-specific variables in the vault that can be removed.

- [ ] **Step 4: Commit vault changes**

```bash
git add roles/services/vars/main/env_vault.yml
git commit -m "Ansible|Update: added traefik env vars to vault, removed npm vars"
```

---

### Task 13: End-to-end verification

- [ ] **Step 1: Run linting**

```bash
uv run yamllint .
uv run ansible-lint
```

Expected: No errors on modified files.

- [ ] **Step 2: Deploy to server**

```bash
uv run ansible-playbook playbooks/update_home_server.yml
```

- [ ] **Step 3: Verify Traefik is running**

SSH to the server and check:

```bash
docker logs traefik 2>&1 | head -50
```

Expected: Traefik starts, loads Docker provider and file provider, no errors.

- [ ] **Step 4: Verify wildcard certificate**

```bash
# Check that acme.json has been created and contains a certificate
docker exec traefik cat /acme/acme.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['cloudflare']['Certificates'][0]['domain']['main'])"
```

Expected: Output shows `dynabase.nl` with SANs `*.dynabase.nl`.

- [ ] **Step 5: Verify Traefik dashboard**

Open `https://traefik.dynabase.nl` in a browser. Should show the Traefik dashboard with all discovered routers and services.

- [ ] **Step 6: Spot-check services from each category**

Test one service per category to verify routing:

```bash
# From the server or a machine on the same network
curl -skL https://jellyfin.dynabase.nl     # Media
curl -skL https://homarr.dynabase.nl        # Dashboards
curl -skL https://beszel.dynabase.nl        # Monitoring
curl -skL https://nextcloud.dynabase.nl     # Storage
curl -skL https://immich.dynabase.nl        # Photos
curl -skL https://frigate.dynabase.nl       # Security
curl -skL https://it-tools.dynabase.nl      # Tools
curl -skL https://zerobyte.dynabase.nl      # Backups
curl -skL https://romm.dynabase.nl          # Games
curl -skL https://ha.dynabase.nl            # Home Assistant (file provider)
curl -skL https://qbittorrent.dynabase.nl   # VPN-routed (via Gluetun)
```

Expected: Each returns an HTTP 200 or redirect to login page (not a 404 or connection refused).

- [ ] **Step 7: Verify HTTP to HTTPS redirect**

```bash
curl -sI http://jellyfin.dynabase.nl | head -5
```

Expected: `HTTP/1.1 301 Moved Permanently` with `Location: https://jellyfin.dynabase.nl/`

- [ ] **Step 8: Clean up old NPM data on the server**

After confirming everything works, remove the old NPM data:

```bash
# On the server
rm -rf ~/services/networking/nginx-proxy-manager/
```

- [ ] **Step 9: Final commit**

```bash
git commit -m "Services|Remove: cleaned up nginx proxy manager references" --allow-empty
```
