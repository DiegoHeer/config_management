# Configuration Management

Personal infrastructure-as-code for automatically setting up Ubuntu home servers, laptops, and desktops. Three pillars:

- **Ansible playbooks** for automatic system configuration
- **Docker Compose services** for containerized home lab applications
- **Restic Profile** for automated backups using the 3-2-1 Backup Rule

## Project Structure

```
roles/          # Ansible roles: system, development, gui, projects, services, restore
playbooks/      # Playbooks: home_server.yml, laptop.yml
services/       # Docker Compose service groups (12 categories)
backup/         # Restic backup profiles and config
molecule/       # Ansible role testing (one scenario per role)
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

2. Generate an SSH key (skip passphrases when prompted):

```bash
ssh-keygen -t ed25519 -C <email address>
```

3. Copy the public key to each managed host:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519 <host user>@<host ip address>
```

4. Edit `inventory.yml` — add hosts and adjust variables as needed.

5. Verify connectivity:

```bash
uv run ansible <host group> -m ping
```

### Usage

1. Create a `.vault_key` file in the repo root with your Ansible vault password. All `vault.yml` files require this password to decrypt. Substitute vault files in roles if needed (check each task to verify which variables come from a `vault.yml`).

2. Run a playbook:

```bash
uv run ansible-playbook playbooks/<playbook>.yml
```

Or with an interactive vault prompt:

```bash
uv run ansible-playbook playbooks/<playbook>.yml --ask-vault-pass
```

#### Ansible Pull (optional)

Playbooks can run locally on the target server using `ansible-pull`:

```bash
sudo apt update
sudo apt install ansible -y
ansible-pull -U git@github.com:DiegoHeer/config_management.git --vault-password-file .vault_key --ask-become-pass
```

### Testing

Testing is done with [Molecule](https://ansible.readthedocs.io/projects/molecule/). Available roles: `system`, `projects`, `development`, `gui`, `restore`, `services`

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

## Backups

Automated backups use [Restic](https://restic.net) and [Restic Profile](https://creativeprojects.github.io/resticprofile/index.html), following the 3-2-1 Backup Rule (3 copies, different media, one offsite).

### Setup

1. Install restic and restic profile:

```bash
sudo apt install restic curl -y
curl -sfL https://raw.githubusercontent.com/creativeprojects/resticprofile/master/install.sh | sh
```

2. Enter the backup folder:

```bash
cd backup
```

3. Create the restic password file:

```bash
echo <password> > .resticprofile_key
```

4. Create an `.env` file by copying `.env.template` and fill in the required variables.

5. Edit `profiles.yaml` if needed (backup sources and repository locations).

### Usage

```bash
# List available profiles
resticprofile profiles

# Initialize a new repository
resticprofile -n <profile> init

# Check existing snapshots
resticprofile -n <profile> snapshots

# Run a backup
resticprofile -n <profile> backup

# Restore to a target directory
resticprofile -n <profile> restore latest --target <target directory>
```

---

## Docker Compose Services

Each service category lives in `services/<category>/` with its own `docker-compose.yaml` and `.env` file.

### Setup

1. For each service category, create an `.env` file inside its directory and fill in the required environment variables (refer to the `docker-compose.yaml` for which variables are needed).

2. Ensure all volume mount paths exist locally. You can restore them from a backup if available:

```bash
cd backup
export $(grep -v "^#" .env | xargs -d "\n")
resticprofile -n services restore latest --target /
```

3. Start the services:

```bash
cd services/<category>
docker compose up -d
```
