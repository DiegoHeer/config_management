# Extract `setup-ansible-deps` Composite Action

**Date**: 2026-03-12
**Status**: Draft

## Problem

The `quality-check.yml` workflow duplicates 7 setup steps across its `lint` and `molecule` jobs. These same steps also exist in the `setup-ansible` composite action, which bundles them with deployment-specific concerns (SSH, Tailscale, inventory). There is no reusable unit for just the Ansible dependency chain.

## Solution

Create a new lightweight composite action `setup-ansible-deps` that encapsulates the shared Ansible dependency setup. Slim down `setup-ansible` to only contain deployment connectivity steps, and have all workflows call `setup-ansible-deps` directly.

## New Action: `.github/actions/setup-ansible-deps/action.yml`

**Inputs:**

| Input            | Required | Description                  |
|------------------|----------|------------------------------|
| `vault-password` | false    | Ansible vault password       |

**Steps (in order):**

All `run:` steps must specify `shell: bash` (required for composite actions).

1. Set up Python 3.14 (`actions/setup-python@v5`)
2. Install uv (`astral-sh/setup-uv@v5`)
3. Cache uv virtualenv (`actions/cache@v4`, path: `.venv`, key: `uv-${{ hashFiles('uv.lock') }}`)
4. Install dependencies (`uv sync`)
5. Cache Galaxy roles (`actions/cache@v4`, path: `.venv/.ansible/roles`, key: `galaxy-${{ hashFiles('requirements.yml') }}`)
6. Install Galaxy roles (`uv run ansible-galaxy install -r requirements.yml`)
7. **Conditional**: Create `.vault_key` file, guarded by `if: inputs.vault-password != ''`

## Changes to Existing Files

### `.github/actions/setup-ansible/action.yml`

- **Remove** all dependency steps (Python, uv, cache, sync, Galaxy, vault key)
- **Remove** `vault-password` input
- **Keep** only deployment-specific steps:
  1. SSH agent setup (`webfactory/ssh-agent@v0.9.0`)
  2. Tailscale connection (`tailscale/github-action@v4`)
  3. Deploy inventory creation
- **Keep** remaining inputs: `ssh-private-key`, `tailscale-oauth-client-id`, `tailscale-oauth-client-secret`, `tailscale-server-ip`, `server-user`
- **Update** description to note it expects `setup-ansible-deps` to have run first

### `.github/workflows/quality-check.yml`

Both `lint` and `molecule` jobs replace their 7 setup steps with a single action call:

```yaml
- name: Setup Ansible dependencies
  uses: ./.github/actions/setup-ansible-deps
  with:
    vault-password: ${{ secrets.VAULT_PASSWORD }}
```

The Checkout step and the job-specific commands (yamllint/ansible-lint, molecule test) remain unchanged.

### `.github/workflows/update-home-server.yml`

Replace the single `setup-ansible` call with two sequential calls:

```yaml
- name: Setup Ansible dependencies
  uses: ./.github/actions/setup-ansible-deps
  with:
    vault-password: ${{ secrets.VAULT_PASSWORD }}

- name: Setup Ansible environment
  uses: ./.github/actions/setup-ansible
  with:
    ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
    tailscale-oauth-client-id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
    tailscale-oauth-client-secret: ${{ secrets.TAILSCALE_OAUTH_CLIENT_SECRET }}
    tailscale-server-ip: ${{ secrets.TAILSCALE_SERVER_IP }}
    server-user: ${{ secrets.SERVER_USER }}
```

### `.github/workflows/restore-home-server.yml`

Same change as `update-home-server.yml` — split into two sequential action calls.

## Files Changed

| File | Change |
|------|--------|
| `.github/actions/setup-ansible-deps/action.yml` | **New** — base dependency action |
| `.github/actions/setup-ansible/action.yml` | **Modified** — remove dependency steps and `vault-password` input |
| `.github/workflows/quality-check.yml` | **Modified** — use `setup-ansible-deps` in both jobs |
| `.github/workflows/update-home-server.yml` | **Modified** — call both actions sequentially |
| `.github/workflows/restore-home-server.yml` | **Modified** — call both actions sequentially |

## Design Decisions

- **`vault-password` is optional at the action level** so it can be used in contexts where vault decryption is not needed. However, deployment workflows (`update-home-server.yml`, `restore-home-server.yml`) and the quality check workflow must always provide it since they run encrypted playbooks or linting that requires vault access.
- **Workflows call both actions sequentially** rather than nesting `setup-ansible-deps` inside `setup-ansible`. This keeps the dependency graph flat and explicit, making it clear what each workflow requires.
- **Action named `setup-ansible-deps`** to clearly convey it handles the dependency chain, distinguishing it from `setup-ansible` which handles deployment connectivity.
