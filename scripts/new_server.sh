#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INVENTORY="$REPO_ROOT/inventory.yml"
VAULT_KEY="$REPO_ROOT/.vault_key"
SSH_KEY="$HOME/.ssh/id_ed25519"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $*"; }
err()  { echo -e "${RED}✗${NC} $*" >&2; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
info() { echo -e "  $*"; }

echo -e "${BOLD}=== Home Server Bootstrap ===${NC}"
echo

# --- Pre-requisite checks ---

echo -e "${BOLD}Checking pre-requisites...${NC}"

if [[ -f "$VAULT_KEY" ]]; then
    ok ".vault_key found"
else
    err ".vault_key not found at $VAULT_KEY"
    info "Create it with your Ansible vault password before continuing."
    exit 1
fi

if [[ -f "$SSH_KEY" ]]; then
    ok "SSH key found at $SSH_KEY"
else
    err "SSH key not found at $SSH_KEY"
    info "Generate one with: ssh-keygen -t ed25519"
    exit 1
fi

echo

# --- Inventory update ---

current_ip=$(grep -A2 'home_server:' "$INVENTORY" | grep 'ansible_host:' | awk '{print $2}')
echo -e "${BOLD}Current target host:${NC} $current_ip"

while true; do
    read -rp "New server IP address [${current_ip}]: " new_ip
    new_ip="${new_ip:-$current_ip}"
    if [[ "$new_ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        break
    fi
    warn "Invalid IP address format, try again."
done

if [[ "$new_ip" != "$current_ip" ]]; then
    sed -i "/home_server:/{n;s/ansible_host: .*/ansible_host: ${new_ip}/}" "$INVENTORY"
    ok "Updated inventory.yml: $current_ip → $new_ip"
else
    info "IP unchanged, inventory not modified."
fi

echo

# --- SSH connectivity test ---

echo -e "${BOLD}Testing SSH connectivity...${NC}"
if ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no \
       -i "$SSH_KEY" "diego@${new_ip}" exit 2>/dev/null; then
    ok "SSH connection to $new_ip successful"
else
    warn "SSH connection to $new_ip failed — ensure the server is up and the key is authorized"
    info "You can still proceed; the playbook will fail if SSH is not available."
fi

echo

# --- Install dependencies ---

echo -e "${BOLD}Installing dependencies...${NC}"
cd "$REPO_ROOT"
uv sync
ok "uv sync complete"

uv run ansible-galaxy install -r requirements.yml
ok "Ansible Galaxy roles installed"

echo

# --- Run playbook ---

read -rp "$(echo -e "${BOLD}Run the playbook now?${NC} [Y/n]: ")" run_now
run_now="${run_now:-Y}"

if [[ "$run_now" =~ ^[Yy]$ ]]; then
    echo
    uv run ansible-playbook playbooks/home_server.yml
else
    echo
    info "Run the playbook manually when ready:"
    info "  uv run ansible-playbook playbooks/home_server.yml"
fi
