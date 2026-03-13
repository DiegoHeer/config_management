# Configuration Management

Personal infrastructure-as-code for automatically setting up Ubuntu home servers. Three pillars:

- **Ansible playbooks** for automatic system configuration
- **Docker Compose services** for containerized home lab applications
- **Restic backups** implementing the 3-2-1 backup rule (managed by the Ansible restore role)

## Project Structure

```
roles/          # Ansible roles: system, projects, services, restore
playbooks/      # Playbooks: update_home_server.yml, restore_home_server.yml
services/       # Docker Compose service groups (11 categories)
molecule/       # Ansible role testing (one scenario per role)
.github/        # CI workflows and shared composite actions
```

### Services Overview

| Category | Services |
|---|---|
| **Home Assistant** | Home Assistant, Mosquitto (MQTT), OpenThread Border Router, Matter Server, Doorbell Samba |
| **Media** | Jellyfin, Seerr, Gluetun (VPN), qBittorrent, Prowlarr, Sonarr, Radarr, Profilarr, SABnzbd, Navidrome, Audiobookshelf, Booklore |
| **Networking** | Nginx Proxy Manager, Cloudflare Tunnel |
| **Monitoring** | Beszel, AdGuard Home, Portracker |
| **Storage** | Filebrowser, Nextcloud, Obsidian LiveSync |
| **Photos** | Immich (server + ML), Redis, PostgreSQL |
| **Tools** | IT-Tools, BentoPDF, Grist, Docuseal, Changedetection, Tandoor, Dockhand |
| **Dashboards** | Homarr, Glance, Dashdot, Homepage |
| **Security** | Frigate (NVR) |
| **Games** | RomM |
| **Backups** | Zerobyte, Databasus |

---

## Ansible

### Requirements

- Ubuntu 24.04 (other versions/distros untested)
- Python >= 3.14
- uv >= 0.6.0

### Setup

1. Install packages and Ansible Galaxy roles:

```bash
uv sync
uv run ansible-galaxy install -r requirements.yml
```

2. Create a `.vault_key` file in the repo root with your Ansible vault password (see Secret Management below).

### Secret Management

Secrets are managed with [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html). The vault password is read from `.vault_key` (configured in `ansible.cfg`). Four encrypted vault files exist across roles:

| Vault file | Contents |
|---|---|
| `roles/system/vars/main/vault.yml` | User password (`vault_password`) |
| `roles/projects/vars/main/vault.yml` | Project-specific secrets |
| `roles/restore/vars/main/vault.yml` | Backup/restore credentials |
| `roles/services/vars/main/env_vault.yml` | All Docker service env vars (`vault_services_env`) |

#### Service environment sync

Docker Compose services need `.env` files with secrets. The script `scripts/sync_env_to_vault.py` handles syncing local `.env` files into the encrypted vault:

1. Reads `.env` files from each `services/<category>/` directory
2. Builds a `vault_services_env` YAML dictionary (service name → key/value pairs)
3. Encrypts and writes it to `roles/services/vars/main/env_vault.yml`

Run the sync script whenever `.env` files change:

```bash
uv run python scripts/sync_env_to_vault.py
```

During deployment, the Ansible `services` role reads `vault_services_env` and templates `.env` files onto the target server (see `roles/services/tasks/env.yml`).

#### Editing vault files

```bash
# View an encrypted vault file
uv run ansible-vault view roles/<role>/vars/main/vault.yml

# Edit an encrypted vault file in-place
uv run ansible-vault edit roles/<role>/vars/main/vault.yml
```

### Deployment

Deployments are handled through GitHub Actions workflows (triggered manually via `workflow_dispatch`):

- **Update Home Server** — runs `update_home_server.yml` (system + projects + services roles)
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

Each service category lives in `services/<category>/` with its own `docker-compose.yaml`. Environment variables are managed through Ansible vault and deployed as `.env` files during provisioning (see Secret Management above).

### Setup

1. For each service category, ensure an `.env` file exists in its directory with the required environment variables (refer to the `docker-compose.yaml` for which variables are needed). During Ansible deployment, `.env` files are generated automatically from vault.

2. Ensure all volume mount paths exist locally. You can restore them from a backup by running the Ansible `restore` role, which handles Restic-based restoration automatically.

3. Start the services:

```bash
cd services/<category>
docker compose up -d
```
