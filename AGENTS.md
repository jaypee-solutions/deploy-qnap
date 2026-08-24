# AGENTS.md

## Scope

This repository contains Ansible playbooks and the `immich` role for deploying
Immich on a QNAP TS-673A running QTS 5.x and x86_64. The controller is expected
to be macOS or Linux with Ansible, `direnv`, and the 1Password CLI available.

The repository's [OKF knowledge bundle](.okf/index.md) captures the durable
deployment model and operational guardrails. Update it when a code or
configuration change changes those facts.

## Safety and secrets

- Never print, decrypt, copy, or commit the contents of
  `inventory/group_vars/qnap/vault.yml` or the 1Password vault password.
- Keep credentials in Ansible Vault and obtain the vault password through
  `.envrc`/`.vault_pass_1p.sh`; do not replace that flow with plaintext files.
- Treat the QNAP as a real deployment target. Do not run destructive Docker,
  database, filesystem, or upgrade commands unless the task explicitly
  authorizes them.
- Preserve unrelated staged and unstaged changes. Scope edits and staging to
  the requested files.

## Deployment rules

- `immich-install.yml` installs or updates the stack; `immich-backup.yml` runs
  the on-demand PostgreSQL backup.
- Before an Immich upgrade, run the backup playbook and verify that a new,
  non-empty `immich_db_*.sql.gz` exists in the configured backup directory.
  A healthy container or a VectorChord image is not proof of a restorable
  backup.
- Keep Immich and database image versions aligned with the official release
  compose file. Preserve image digests unless an intentional update includes
  a replacement digest and validation.
- The role owns the compose file, `.env`, backup script, directories, and
  backup cron. Edit the templates/defaults rather than generated files on the
  QNAP.

## Controller and QNAP quirks

- Use the repository's `ansible.cfg`; do not silently select another config
  through `ANSIBLE_CONFIG`.
- `RequestTTY=no` is required for the QNAP SSH shell. Recent macOS OpenSSH
  rejects a literal `%(here)s` in `ssh_args`; keep known-host handling in the
  standard SSH configuration used by `ansible.cfg`.
- If Ansible's default temporary directory is blocked on macOS, use
  `ANSIBLE_LOCAL_TEMP=/private/tmp/ansible-local` for the command.
- Avoid unescaped Docker Go-template expressions such as `{{...}}` in inline
  Ansible shell commands; Ansible will interpret them as Jinja.

## Validation

For controller-only changes, prefer these checks before handoff:

```bash
ansible-playbook --syntax-check immich-install.yml
ansible-playbook --syntax-check immich-backup.yml
git diff --check
```

For a connectivity check against the real QNAP, use the isolated temporary
directory when needed:

```bash
ANSIBLE_LOCAL_TEMP=/private/tmp/ansible-local ansible qnap -m ansible.builtin.ping
```

Do not treat syntax or ping success as proof that a backup is restorable. For
backup and upgrade work, inspect the resulting remote artifact and report its
size and timestamp without exposing its contents.

## Change style

- Keep YAML and Jinja readable, use descriptive task names, and make changes
  narrowly in the relevant playbook, role default, task, or template.
- Do not add Microsoft or Meta-specific tooling when an existing Python,
  Ansible, macOS, Linux, or open-source workflow covers the need.
- Before committing, validate the affected OKF bundle with the repository's
  OKF validator and include the relevant checks in the handoff.
