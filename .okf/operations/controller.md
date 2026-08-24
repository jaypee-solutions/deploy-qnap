---
type: Runbook
title: Ansible controller and QNAP SSH behavior
description: Repository-local Ansible settings account for the QNAP shell and recent macOS OpenSSH behavior.
tags: [ansible, ssh, macos, linux, qnap]
timestamp: 2026-08-24T07:09:28+02:00
---

# Configuration

[ansible.cfg](/ansible.cfg) selects the repository inventory, enables
pipelining, uses `/tmp/.ansible/tmp` remotely, and sets `RequestTTY=no` so the
QNAP interactive management shell does not take over the Ansible command.

Recent macOS OpenSSH rejects a literal `%(here)s` placeholder in `ssh_args`.
The repository therefore uses `StrictHostKeyChecking=accept-new` and the
standard SSH known-host handling rather than a `UserKnownHostsFile=%(here)s`
override.

# Diagnostics

Run commands from this checkout so the intended configuration is selected. If
the macOS sandbox or local permissions block Ansible's temporary directory,
set `ANSIBLE_LOCAL_TEMP=/private/tmp/ansible-local`. A useful connectivity
check is:

```bash
ANSIBLE_LOCAL_TEMP=/private/tmp/ansible-local \
  ansible qnap -m ansible.builtin.ping
```

An earlier controller fix was verified with `ping: pong` on 2026-07-26. If the
`vdollar_percent_expand: unknown key %(` error returns, inspect the effective
Ansible configuration and SSH arguments before changing the QNAP deployment.

# Caveat

Inline Ansible shell commands containing Docker Go-template syntax such as
`{{...}}` are parsed as Jinja. Avoid that syntax in diagnostic commands or
escape it deliberately.

# Module result deserialization

Ansible-core 2.19 and newer use serialization profiles for module results. If
a task reports `Module result deserialization failed: Unknown profile name
'module_legacy_m2c'`, inspect the returned `module_stdout`, `module_stderr`, and
`rc` before rerunning a potentially expensive or state-changing command. The
remote module can have completed successfully even though the controller could
not decode its result.

On 2026-08-24, the QNAP backup returned `rc=0` and created a 369M
`immich_db_20260824_064348.sql.gz` artifact despite this controller error. A
separate harmless `shell: true` test succeeded with Ansible `core 2.21.3` and
the QNAP Python `3.12.6`, so this incident does not establish a persistent
playbook or target-Python incompatibility.

# Citations

[1] [Ansible 12 porting guide: module result serialization](https://github.com/ansible/ansible-documentation/blob/devel/docs/docsite/rst/porting_guide_12.rst)

[2] [Ansible issue #85668: matching deserialization failure](https://github.com/ansible/ansible/issues/85668)

[3] [Ansible-core support matrix](https://docs.ansible.com/ansible/latest/reference_appendices/release_and_maintenance.html)
