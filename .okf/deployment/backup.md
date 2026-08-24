---
type: Runbook
title: Immich PostgreSQL backup workflow
description: The role generates a compressed pg_dumpall backup script and schedules it nightly on the QNAP.
tags: [immich, backup, postgres, qnap, recovery]
timestamp: 2026-08-23T00:00:00+02:00
---

# Entry points

The [on-demand backup playbook](/immich-backup.yml) executes
`/share/Container/immich/immich-backup.sh` by default. The role also installs a
QNAP cron entry at `03:00`, appending output to `backup.log` in the backup
directory.

# Artifact

The generated [backup template](/roles/immich/templates/immich-backup.sh.j2)
creates a file named `immich_db_YYYYMMDD_HHMMSS.sql.gz` under
`immich_backup_dir`. It runs `pg_dumpall --clean --if-exists` inside the
`immich_postgres` container, streams the dump through `gzip`, and deletes
matching files older than `immich_backup_keep_days` (seven days by default).

The shell script uses `set -euo pipefail` and a non-TTY Docker exec so pipeline
failures are not silently converted into successful-looking empty artifacts.

# Verification

Before an upgrade, execute the playbook and verify that a newly created dump is
non-empty. Report its path, size, and timestamp only; never print or copy its
contents. A running database container, a pinned image, or a configured cron
entry does not establish that a restorable backup exists.

A readiness check on 2026-07-26 found the managed backup directory empty and no
`immich-backup` cron entry on the live QNAP. That is historical evidence only;
recheck the live target before relying on the backup workflow.

# Related concepts

The backup is a prerequisite of the [upgrade gate](/operations/upgrade-gate.md).
