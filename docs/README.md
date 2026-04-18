# Documentation

Reference documentation for the gitops-homelab repo. Kept intentionally short
— the code + commit history are the primary sources of truth.

## Contents

- **[adr/](adr/)** — Architectural Decision Records. Load-bearing choices
  about the architecture, recorded once and preserved for future-you.
- **[runbooks/](runbooks/)** — Operational runbooks. Written reactively
  when an incident or operation is non-obvious enough to deserve a
  permanent how-to.

## Conventions

- ADRs use the Nygard template (`adr/template.md`). Accepted ADRs are
  never edited; supersede them with a new ADR.
- Runbooks use the template at `runbooks/template.md`. One file per
  procedure.
- Filenames are kebab-case; ADRs are prefixed with a 4-digit number.
