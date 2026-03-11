# Configuration Management

Personal infrastructure-as-code for automatically setting up Ubuntu home servers, laptops, and desktops. Three pillars:

- **Ansible playbooks** for automatic system configuration
- **Docker Compose services** for containerized home lab applications
- **Restic backups** implementing the 3-2-1 backup rule (managed by the Ansible restore role)

## Project Structure

```
roles/          # Ansible roles: system, projects, services, restore
playbooks/      # Playbooks: update_home_server.yml, restore_home_server.yml
services/       # Docker Compose service groups (12 categories)
molecule/       # Ansible role testing (one scenario per role)
.github/        # CI workflows and shared composite actions
```

### Services Overview

| Category | Services |
|---|---|
| **Home Assistant** | Home Assistant, Mosquitto (MQTT), Doorbell Samba |
| **Media** | Jellyfin, Seerr, Gluetun (VPN), qBittorrent, Prowlarr, Sonarr, Radarr, Profilarr, FlareSolverr, SABnzbd, Navidrome, Audiobookshelf, Booklore |
| **Networking** | Nginx Proxy Manager, Cloudflare Tunnel |
| **Monitoring** | Beszel, AdGuard Home, Portracker, Termix |
| **Storage** | Filebrowser, Nextcloud, Obsidian LiveSync |
| **Photos** | Immich (server + ML), Redis, PostgreSQL |
| **Tools** | IT-Tools, BentoPDF, Grist, n8n, Docuseal, Changedetection, Tandoor, Karakeep, Dockhand, Dash |
| **Dashboards** | Homarr, Glance |
| **Security** | Frigate (NVR) |
| **Games** | RomM |
| **Backups** | Zerobyte, Databasus |

---

## Ansible

### Requirements

- Ubuntu 24.04 (other versions/distros untested)
- Python >= 3.11
- uv >= 0.6.0

### Setup

1. Install packages and Ansible Galaxy roles:

```bash
uv sync
uv run ansible-galaxy install -r requirements.yml
```

2. Create a `.vault_key` file in the repo root with your Ansible vault password. All `vault.yml` files require this password to decrypt. Substitute vault files in roles if needed (check each task to verify which variables come from a `vault.yml`).

### Deployment

Deployments are handled through GitHub Actions workflows (triggered manually via `workflow_dispatch`):

- **Update Home Server** — runs `update_home_server.yml` (system + services roles)
- **Restore Home Server** — runs `restore_home_server.yml` (system + projects + restore + services roles)

Both workflows use a shared composite action (`.github/actions/setup-ansible/`) that handles Python/uv setup, Galaxy roles, vault key, SSH, and Tailscale connectivity.

### Testing

Testing is done with [Molecule](https://ansible.readthedocs.io/projects/molecule/). Available scenarios: `system`, `projects`, `restore`, `services`

```bash
# Run the full test sequence
molecule test -s <role>

# Converge only (apply the role)
molecule converge -s <role>

# Shell into the test container
molecule login -s <role>

# Tear down test containers
molecule destroy -s <role>
```

To create a new test scenario:

```bash
molecule init scenario <role/playbook name>
```

After creation, delete `creation.yml` and `destroy.yml`, then edit `molecule.yml` to match the setup of existing scenarios. Update `converge.yml` to reference the new role/playbook.

### Linting

```bash
uv run yamllint .
uv run ansible-lint
```

---

## Docker Compose Services

Each service category lives in `services/<category>/` with its own `docker-compose.yaml` and `.env` file.

### Setup

1. For each service category, create an `.env` file inside its directory and fill in the required environment variables (refer to the `docker-compose.yaml` for which variables are needed).

2. Ensure all volume mount paths exist locally. You can restore them from a backup by running the Ansible `restore` role, which handles Restic-based restoration automatically.

3. Start the services:

```bash
cd services/<category>
docker compose up -d
```
