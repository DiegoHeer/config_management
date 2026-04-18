#!/usr/bin/env python3
"""Sync encrypted Ansible vault back to services .env files."""

import sys
from pathlib import Path

import yaml
from ansible.constants import DEFAULT_VAULT_ID_MATCH
from ansible.parsing.vault import VaultLib, VaultSecret

REPO_ROOT = Path(__file__).resolve().parent.parent
SERVICES_DIR = REPO_ROOT / "services"
VAULT_KEY_FILE = REPO_ROOT / ".vault_key"
VAULT_OUTPUT = REPO_ROOT / "roles" / "docker_host" / "vars" / "main" / "env_vault.yml"


def load_existing_vault(vault: VaultLib) -> dict[str, dict[str, str]]:
    """Decrypt and parse the existing vault file, returning the services env dict."""
    if not VAULT_OUTPUT.exists():
        return {}
    decrypted = vault.decrypt(VAULT_OUTPUT.read_bytes())
    data = yaml.safe_load(decrypted)
    if data and "vault_docker_host_env" in data:
        return data["vault_docker_host_env"]
    return {}


def write_env_file(path: Path, env_vars: dict[str, str]) -> None:
    """Write a dict of env vars to a .env file in KEY=VALUE format."""
    content = "".join(f"{key}={value}\n" for key, value in env_vars.items())
    path.write_text(content)
    path.chmod(0o600)


def main() -> int:
    if not VAULT_KEY_FILE.exists():
        print(f"Error: Vault key file not found at {VAULT_KEY_FILE}", file=sys.stderr)
        return 1

    vault_key = VAULT_KEY_FILE.read_text().strip()
    vault = VaultLib([(DEFAULT_VAULT_ID_MATCH, VaultSecret(vault_key.encode()))])

    services_env = load_existing_vault(vault)
    if not services_env:
        print("No services found in vault", file=sys.stderr)
        return 1

    written = 0
    skipped = 0
    for service_name in sorted(services_env):
        service_dir = SERVICES_DIR / service_name
        if not service_dir.is_dir():
            print(f"Warning: skipping '{service_name}' — directory {service_dir} does not exist", file=sys.stderr)
            skipped += 1
            continue
        write_env_file(service_dir / ".env", services_env[service_name])
        written += 1

    print(f"Wrote {written} .env file(s) from vault")
    if skipped:
        print(f"Skipped {skipped} service(s) with no local directory")
    return 0


if __name__ == "__main__":
    sys.exit(main())
