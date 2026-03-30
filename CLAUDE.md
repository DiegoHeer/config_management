# CLAUDE.md

## Project Overview

Personal IaC repository for Ubuntu home servers. Three pillars:
- **Ansible playbooks** for automatic system configuration
- **Docker Compose services** for containerized home lab applications
- **Restic backups** implementing the 3-2-1 backup rule

## Project Structure

```
roles/          # Ansible roles: system, projects, services, restore
playbooks/      # Playbooks: update_home_server.yml, restore_home_server.yml
services/       # Docker Compose service groups (12 categories)
molecule/       # Ansible role testing (one scenario per role)
.github/        # CI workflows and shared composite actions
```

Service categories: ai, home_assistant, media, monitoring, storage, tools, dashboards, security, photos, backups, networking, games

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

- Files at `services/<category>/docker-compose.yaml`
- Container names: snake_case, matching the service key
- All services on external `home_server_network` bridge
- Config/data volumes use `./` relative paths (e.g. `./beszel:/beszel_data`)
- Media/data volumes on `/media/hd1-3/`
- VPN-routed services use `network_mode: service:gluetun`
- Health checks on all services (curl/wget, 30s interval, 10s timeout, 3-5 retries)
- Restart policy: `unless-stopped`
- Env vars sourced from `.env` files (never committed; generated from Ansible vault)

### YAML

- Max line length: 120 characters (yamllint)
- Files use `.yaml` extension

## Secrets

- Never commit `.env` files or vault passwords
- Ansible vault key: `.vault_key` (root dir)
- `.env` files are generated from Ansible vault; reference `docker-compose.yaml` for required variables
