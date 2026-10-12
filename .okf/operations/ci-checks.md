---
type: Runbook
title: CI checks
description: GitHub Actions run TruffleHog secret scanning and ansible-lint on pull requests and main.
tags: [ci, github-actions, trufflehog, ansible-lint, secrets]
timestamp: 2026-10-12T19:50:00+02:00
---

# Workflows

* `.github/workflows/trufflehog.yml` scans pushed or PR commits for verified
  and unknown secrets and fails on any finding.
* `.github/workflows/ansible-lint.yml` lints playbooks and roles with the
  default `production` profile.

Neither workflow receives the Ansible Vault password; the encrypted
`inventory/group_vars/qnap/vault.yml` is never decrypted in CI.

# Lint baseline

`.ansible-lint-ignore` lists the 28 violations that pre-dated the workflow
(missing `changed_when`, `shell` instead of `command`, FQCN, naming and
formatting). New violations fail CI. Remove baseline entries when fixing the
code; see `docs/adr/0003-ci-secret-scan-and-ansible-lint.md`.

# Local reproduction

```bash
env -u ANSIBLE_VAULT_PASSWORD_FILE uvx ansible-lint
trufflehog git file://. --branch HEAD --results=verified,unknown --no-update --fail
```

Unsetting the vault password file keeps the local lint run from decrypting
secrets. On 2026-10-12 both commands passed against `main` with the baseline.

# Maintenance

Actions are pinned by SHA and TruffleHog by version; update them deliberately.
