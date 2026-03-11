# Extract `setup-ansible-deps` Composite Action — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract shared Ansible dependency setup into a reusable composite action, eliminating duplication across all CI workflows.

**Architecture:** A new `setup-ansible-deps` composite action handles Python, uv, caching, Galaxy roles, and optional vault key. The existing `setup-ansible` action is slimmed to only deployment connectivity (SSH, Tailscale, inventory). All workflows call `setup-ansible-deps` directly.

**Tech Stack:** GitHub Actions (composite actions), YAML

**Spec:** `docs/superpowers/specs/2026-03-12-extract-setup-ansible-deps-action-design.md`

---

## Chunk 1: Create base action and refactor workflows

### Task 1: Create `setup-ansible-deps` composite action

**Files:**
- Create: `.github/actions/setup-ansible-deps/action.yml`

- [ ] **Step 1: Create the action file**

```yaml
---
name: Setup Ansible Dependencies
description: >-
  Shared dependency setup for all Ansible workflows: installs Python, uv,
  dependencies, and Galaxy roles. Optionally creates the Ansible vault key.

inputs:
  vault-password:
    description: Ansible vault password (optional — skips vault key creation if omitted)
    required: false

runs:
  using: composite
  steps:
    - name: Set up Python
      uses: actions/setup-python@v5
      with:
        python-version: "3.14"

    - name: Install uv
      uses: astral-sh/setup-uv@v5

    - name: Cache uv virtualenv
      uses: actions/cache@v4
      with:
        path: .venv
        key: uv-${{ hashFiles('uv.lock') }}

    - name: Install dependencies
      shell: bash
      run: uv sync

    - name: Cache Galaxy roles
      uses: actions/cache@v4
      with:
        path: .venv/.ansible/roles
        key: galaxy-${{ hashFiles('requirements.yml') }}

    - name: Install Galaxy roles
      shell: bash
      run: uv run ansible-galaxy install -r requirements.yml

    - name: Create Ansible vault key
      if: inputs.vault-password != ''
      shell: bash
      run: echo "${{ inputs.vault-password }}" > .vault_key
```

- [ ] **Step 2: Validate YAML syntax**

Run: `uv run yamllint .github/actions/setup-ansible-deps/action.yml`
Expected: no errors

- [ ] **Step 3: Commit**

```bash
git add .github/actions/setup-ansible-deps/action.yml
git commit -m "Infrastructure|Add: create setup-ansible-deps composite action"
```

### Task 2: Slim down `setup-ansible` action

**Files:**
- Modify: `.github/actions/setup-ansible/action.yml`

- [ ] **Step 1: Replace action file contents**

Remove all dependency steps (Python, uv, cache, sync, Galaxy, vault key) and the `vault-password` input. Keep only deployment connectivity steps and their inputs. Update description.

New contents:

```yaml
---
name: Setup Ansible Environment
description: >-
  Deployment connectivity for Ansible playbook workflows: sets up SSH,
  Tailscale, and deploy inventory. Expects setup-ansible-deps to have run first.

inputs:
  ssh-private-key:
    description: SSH private key for server access
    required: true
  tailscale-oauth-client-id:
    description: Tailscale OAuth client ID
    required: true
  tailscale-oauth-client-secret:
    description: Tailscale OAuth client secret
    required: true
  tailscale-server-ip:
    description: Tailscale IP of the target server
    required: true
  server-user:
    description: SSH user on the target server
    required: true

runs:
  using: composite
  steps:
    - name: Set up SSH agent
      uses: webfactory/ssh-agent@v0.9.0
      with:
        ssh-private-key: ${{ inputs.ssh-private-key }}

    - name: Connect to Tailscale
      uses: tailscale/github-action@v4
      with:
        oauth-client-id: ${{ inputs.tailscale-oauth-client-id }}
        oauth-secret: ${{ inputs.tailscale-oauth-client-secret }}
        tags: tag:ci

    - name: Create deploy inventory
      shell: bash
      run: |
        cat > deploy_inventory.yml <<EOF
        home_lab:
          hosts:
            home_server:
              ansible_host: ${{ inputs.tailscale-server-ip }}
              ansible_user: ${{ inputs.server-user }}
              ansible_python_interpreter: /usr/bin/python3
          vars:
            username: ${{ inputs.server-user }}
        EOF
```

- [ ] **Step 2: Validate YAML syntax**

Run: `uv run yamllint .github/actions/setup-ansible/action.yml`
Expected: no errors

- [ ] **Step 3: Commit**

```bash
git add .github/actions/setup-ansible/action.yml
git commit -m "Infrastructure|Refactor: slim setup-ansible to deployment connectivity only"
```

### Task 3: Refactor `quality-check.yml`

**Files:**
- Modify: `.github/workflows/quality-check.yml`

- [ ] **Step 1: Replace `lint` job setup steps**

Replace steps 2-8 (Set up Python through Create Ansible vault key) with:

```yaml
      - name: Setup Ansible dependencies
        uses: ./.github/actions/setup-ansible-deps
        with:
          vault-password: ${{ secrets.VAULT_PASSWORD }}
```

Keep the Checkout step before it. Keep yamllint and ansible-lint steps after it.

- [ ] **Step 2: Replace `molecule` job setup steps**

Replace steps 2-8 (Set up Python through Create Ansible vault key) with the same single action call:

```yaml
      - name: Setup Ansible dependencies
        uses: ./.github/actions/setup-ansible-deps
        with:
          vault-password: ${{ secrets.VAULT_PASSWORD }}
```

Keep the Checkout step before it. Keep the Molecule test step after it.

Full resulting file:

```yaml
---
name: Quality Check

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Ansible dependencies
        uses: ./.github/actions/setup-ansible-deps
        with:
          vault-password: ${{ secrets.VAULT_PASSWORD }}

      - name: Run yamllint
        run: uv run yamllint .

      - name: Run ansible-lint
        run: uv run ansible-lint

  molecule:
    name: Molecule - ${{ matrix.scenario }}
    runs-on: ubuntu-latest
    needs: lint
    if: github.event_name == 'workflow_dispatch'
    strategy:
      fail-fast: false
      matrix:
        scenario:
          - system
          - projects
          - services
          - restore
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Ansible dependencies
        uses: ./.github/actions/setup-ansible-deps
        with:
          vault-password: ${{ secrets.VAULT_PASSWORD }}

      - name: Run Molecule
        run: uv run molecule test -s ${{ matrix.scenario }}
```

- [ ] **Step 3: Validate YAML syntax**

Run: `uv run yamllint .github/workflows/quality-check.yml`
Expected: no errors

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/quality-check.yml
git commit -m "Infrastructure|Refactor: use setup-ansible-deps in quality check pipeline"
```

### Task 4: Refactor deployment workflows

**Files:**
- Modify: `.github/workflows/update-home-server.yml`
- Modify: `.github/workflows/restore-home-server.yml`

- [ ] **Step 1: Update `update-home-server.yml`**

Replace the single `setup-ansible` step with two sequential action calls:

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

Keep the Checkout step before and the playbook run step after.

- [ ] **Step 2: Update `restore-home-server.yml`**

Same change as `update-home-server.yml` — replace the single `setup-ansible` step with the same two sequential action calls.

- [ ] **Step 3: Validate YAML syntax**

Run: `uv run yamllint .github/workflows/update-home-server.yml .github/workflows/restore-home-server.yml`
Expected: no errors

- [ ] **Step 4: Validate all workflows with actionlint (if available)**

Run: `which actionlint && actionlint .github/workflows/*.yml || echo "actionlint not installed, skipping"`
Expected: no errors (or skipped)

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/update-home-server.yml .github/workflows/restore-home-server.yml
git commit -m "Infrastructure|Refactor: use setup-ansible-deps in deployment workflows"
```

### Task 5: Final validation

- [ ] **Step 1: Run full yamllint**

Run: `uv run yamllint .`
Expected: no errors

- [ ] **Step 2: Run ansible-lint**

Run: `uv run ansible-lint`
Expected: no errors

- [ ] **Step 3: Verify no duplication remains**

Manually confirm that the Python/uv/cache/Galaxy/vault-key steps appear only in `.github/actions/setup-ansible-deps/action.yml` and nowhere else in `.github/`.
