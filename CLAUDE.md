# CLAUDE.md

## Project Overview

Personal IaC repository for Ubuntu home servers. Three pillars:
- **Ansible playbooks** for automatic system configuration
- **Docker Compose services** for containerized home lab applications
- **Restic backups** implementing the 3-2-1 backup rule

## Project Structure

```
roles/          # Ansible roles: system, projects, services, restore
playbooks/      # Playbooks: home_server.yml
services/       # Docker Compose service groups (14 categories)
backup/         # Restic backup profiles and config
molecule/       # Ansible role testing (one scenario per role)
```

Service categories: home_assistant, media, monitoring, storage, tools, dashboards, security, photos, backups, networking, games, experimental

## Common Commands

```bash
# Dependencies
uv sync
uv run ansible-galaxy install -r requirements.yml

# Run a playbook
uv run ansible-playbook playbooks/<playbook>.yml

# Test a role with Molecule
molecule test -s <role>
molecule converge -s <role>    # converge only
molecule login -s <role>       # shell into test container
molecule destroy -s <role>     # teardown

# Linting
uv run yamllint .
uv run ansible-lint

# Backups (run from backup/ directory)
resticprofile -n <profile> backup
resticprofile -n <profile> snapshots
```

## Conventions

### Git Commits

Format: `Category|Action: description`

- **Categories**: `Services`, `Ansible`, `Infrastructure`, `Config`
- **Actions**: `Add`, `Refactor`, `Remove`, `Fix`, `Update`, `Migrate`

Description should be concise and explain *what* changed. Group commits by change type, not by file.

Examples:
```
Services|Add: included booklore for book management
Services|Remove: removed Go Access from networking stack
Services|Fix: added missing restart policies to mosquitto, cloudflare_tunnel, and tandoor
Services|Refactor: migrated jellyseerr to seerr
Services|Update: updated multiple services to latest versions
```

### Ansible

- Variable naming: `role_function_detail` (e.g. `services_docker_src`)
- Vault variables: `vault_variablename`; stored in `roles/<role>/vars/main/vault.yml`
- Tasks split by functionality into separate files, orchestrated via `include_tasks` in `main.yml`
- Playbooks delegate to roles via `include_role`

### Docker Compose

- Files at `services/<category>/docker-compose.yaml` with matching `.env`
- Container names: snake_case, matching the service key
- All services on external `home_server_network` bridge
- Config volumes: `/home/${USERNAME}/services_data/<service>/config`
- Media/data volumes on `/media/hd1-3/`
- VPN-routed services use `network_mode: service:gluetun`
- Health checks on all services (curl/wget, 30s interval, 10s timeout, 3-5 retries)
- Restart policy: `unless-stopped`
- Env vars sourced from `.env` files (never committed; `.env.template` provided)

### YAML

- Max line length: 120 characters (yamllint)
- Files use `.yaml` extension

### Backups

- Tier naming: `s_tier` (critical), `a_tier` (large), `b_tier`, `c_tier`
- Profile inheritance via `inherit: default`
- Env template syntax: `{{ .Env.VARIABLE_NAME }}`

## Secrets

- Never commit `.env` files or vault passwords
- Ansible vault key: `.vault_key` (root dir)
- Restic key: `backup/.resticprofile_key`
- Use `.env.template` files as reference for required variables
