# CLAUDE.md

## Project Overview

Personal IaC repository for Ubuntu home servers. Three pillars:
- **Ansible playbooks** for one-time host bootstrap (Docker, shared network, SOPS age key, cloudflared token, the DocoCD stack itself)
- **Docker Compose services** for containerized home lab applications, deployed **GitOps-style** by [DocoCD](https://github.com/kimdre/doco-cd)
- **Restic backups** implementing the 3-2-1 backup rule

Day-to-day deploys are `git push`-driven: DocoCD watches this repo, clones on webhook, SOPS-decrypts per-stack env files, and runs `docker compose up` on the host.

## Project Structure

```
.doco-cd.yml        # Registry of DocoCD-managed stacks (one YAML doc per stack)
.sops.yaml          # age recipient for services/**/*.enc.env
bootstrap/gitops/   # DocoCD itself — Ansible-managed (can't redeploy itself)
services/           # Docker Compose stacks (12 DocoCD-managed categories)
roles/              # Ansible roles: system, projects, services, restore
playbooks/          # Playbooks: update_home_server.yml, restore_home_server.yml
molecule/           # Ansible role testing (one scenario per role)
.github/            # CI workflows and shared composite actions
```

Service categories under `services/`: ai, home_assistant, media, monitoring, storage, tools, dashboards, security, photos, backups, networking, games. The DocoCD stack itself lives at `bootstrap/gitops/` because it can't redeploy its own container without killing the in-flight deploy.

## Common Commands

```bash
# Dependencies
uv sync
uv run ansible-galaxy install -r requirements.yml

# Run a playbook (host bootstrap: packages, network, gitops stack)
uv run ansible-playbook playbooks/update_home_server.yml

# Test a role with Molecule
molecule test -s <role>
molecule converge -s <role>    # converge only
molecule login -s <role>       # shell into test container
molecule destroy -s <role>     # teardown

# SOPS (edit encrypted per-stack env)
sops services/<category>/secrets.enc.env

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
Services|Add: included grimmory for book management
Services|Remove: removed Go Access from networking stack
Services|Fix: added missing restart policies to mosquitto, cloudflare_tunnel, and tandoor
Services|Refactor: migrated jellyseerr to seerr
Services|Update: updated multiple services to latest versions
```

### Deploy flow (DocoCD, GitOps)

- Every stack listed in [.doco-cd.yml](.doco-cd.yml) is managed by DocoCD.
- Push to `main` → GitHub webhook → DocoCD clones the repo, decrypts SOPS env files, runs `docker compose up -d` per stack.
- Adding a new stack: create `services/<name>/docker-compose.yaml`, append a `---` block with `name: <name>` and `working_dir: services/<name>` to `.doco-cd.yml`, commit.
- Removing a stack: delete the `---` block from `.doco-cd.yml` and the `services/<name>/` dir. Named volumes and absolute-path bind mounts are preserved (`destroy: false` by default).
- The `bootstrap/gitops/` stack is the exception — it hosts DocoCD itself and is updated via Ansible (see `roles/services/tasks/gitops.yml`). Host location: `~/bootstrap/gitops/`.

### Ansible

- Variable naming: `role_function_detail`
- Vault variables: `vault_variablename`; stored in `roles/<role>/vars/main/vault.yml` (or `env_vault.yml`)
- Tasks split by functionality into separate files, orchestrated via `include_tasks` in `main.yml`
- Playbooks delegate to roles via `include_role`
- The `services` role is now bootstrap-only: install Docker, create `home_server_network`, plant the SOPS age key + cloudflared tunnel token + `services_data/` dir, render the `bootstrap/gitops/` stack's `.env` from vault and sync its compose file. Nothing under it handles runtime deploys.

### Docker Compose

- Files at `services/<category>/docker-compose.yaml`
- Container names: snake_case, matching the service key
- All services on external `home_server_network` bridge
- **Runtime state**: absolute bind mounts under `/home/diego/services_data/<category>/<service>/` (so `destroy: true` never eats user data and Restic backups just point at one tree)
- **Static config checked into git**: relative bind mounts from the compose file's own dir (e.g. `./traefik/traefik.yml:/traefik.yml:ro`); DocoCD serves these from its clone
- Media/data volumes on `/media/hd1-3/`
- VPN-routed services use `network_mode: service:gluetun`
- Health checks on all services (curl/wget, 30s interval, 10s timeout, 3-5 retries)
- Restart policy: `unless-stopped`
- Env vars sourced from `env_file: secrets.enc.env` (SOPS + age-encrypted, **committed to git**). Per-service split files are fine when two services in the same stack need the same env var name with different values (e.g. `services/ai/{paperclip,n8n}.enc.env`).
- Put **final container env var names** directly into `secrets.enc.env`. Compose's `${VAR}` interpolation does NOT read `env_file` contents — `environment: - X=${Y}` resolves to empty string when `Y` is only in `env_file`.

### YAML

- Max line length: 120 characters (yamllint)
- Files use `.yaml` extension

## Secrets

- Per-stack service env: **SOPS + age**, committed as `services/<cat>/*.enc.env`. Recipient in [.sops.yaml](.sops.yaml). Edit with `sops services/<cat>/secrets.enc.env`.
- The age secret key itself lives in Ansible vault (`vault_sops_age_key`) and is planted onto the host by `roles/services/tasks/gitops.yml`.
- `bootstrap/gitops/` stack's own `.env` (contains `WEBHOOK_SECRET` + `SOPS_AGE_KEY` for the DocoCD container) is templated by Ansible from `vault_services_env.gitops` — it can't be SOPS-encrypted because DocoCD itself needs it at startup.
- Cloudflare tunnel token lives in vault (`vault_cloudflared_tunnel_token`) and is planted at `~/.config/cloudflared/tunnel_token` by Ansible; the networking stack reads it via `--token-file` (docker secret).
- Never commit plaintext `.env` files or vault passwords.
- Ansible vault key: `.vault_key` (root dir, gitignored).
