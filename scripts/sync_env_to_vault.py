#!/usr/bin/env python3
"""Sync services .env files into an encrypted Ansible vault file."""

import sys
from pathlib import Path

from ansible.constants import DEFAULT_VAULT_ID_MATCH
from ansible.parsing.vault import VaultLib, VaultSecret

REPO_ROOT = Path(__file__).resolve().parent.parent
SERVICES_DIR = REPO_ROOT / "services"
VAULT_KEY_FILE = REPO_ROOT / ".vault_key"
VAULT_OUTPUT = REPO_ROOT / "roles" / "services" / "vars" / "main" / "env_vault.yml"


def parse_env_file(path: Path) -> dict[str, str]:
    """Parse a .env file into a dict, skipping comments and blank lines."""
    env_vars = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key, _, value = line.partition("=")
        env_vars[key.strip()] = value.strip()
    return env_vars


def yaml_quote(value: str) -> str:
    """Quote a YAML value if it contains special characters."""
    special_chars = ":#{}[]&*?|>!%@`'\"\\"
    if not value or any(c in value for c in special_chars):
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        return f'"{escaped}"'
    return value


def build_yaml(services_env: dict[str, dict[str, str]]) -> str:
    """Build YAML string from the services env dictionary."""
    lines = ["---", "vault_services_env:"]
    for service in sorted(services_env):
        lines.append(f"  {service}:")
        for key, value in services_env[service].items():
            lines.append(f"    {key}: {yaml_quote(value)}")
    return "\n".join(lines) + "\n"


def main() -> int:
    if not VAULT_KEY_FILE.exists():
        print(f"Error: Vault key file not found at {VAULT_KEY_FILE}", file=sys.stderr)
        return 1

    vault_key = VAULT_KEY_FILE.read_text().strip()
    vault = VaultLib([(DEFAULT_VAULT_ID_MATCH, VaultSecret(vault_key.encode()))])

    services_env = {}
    for env_file in sorted(SERVICES_DIR.glob("*/.env")):
        service_name = env_file.parent.name
        env_vars = parse_env_file(env_file)
        if env_vars:
            services_env[service_name] = env_vars

    if not services_env:
        print("No .env files found", file=sys.stderr)
        return 1

    yaml_content = build_yaml(services_env)
    encrypted = vault.encrypt(yaml_content)

    VAULT_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    VAULT_OUTPUT.write_bytes(encrypted)
    print(f"Synced {len(services_env)} service .env files to {VAULT_OUTPUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
