---
type: Decision
title: Immich upgrade gate
description: A verified non-empty PostgreSQL dump is required before applying an Immich version update.
tags: [immich, upgrade, backup, safety, qnap]
timestamp: 2026-08-23T21:32:04+02:00
---

# Decision

Do not run [immich-install.yml](/immich-install.yml) for a major or otherwise
risky Immich update until a fresh backup has been created with
[immich-backup.yml](/immich-backup.yml) and its resulting
`immich_db_*.sql.gz` artifact has been verified to be non-empty.

# Sequence

1. Confirm the intended Immich release and its official database image tag.
2. Run the [backup workflow](/deployment/backup.md).
3. Verify the new dump's size and timestamp without exposing its contents.
4. Run the install/update playbook.
5. Monitor startup and allow substantial time for `clip_index` and `face_index`
   reindexing on a large library.

# Rationale

A healthy stack and the presence of a VectorChord-compatible database image do
not demonstrate that a restorable backup exists. The deployed image family and
`vector:0.8.1` extension observed on 2026-07-26 mean the pgvecto.rs migration
path was not applicable to that live instance, but live compatibility must be
rechecked for future upgrades.

The latest stable release checked on 2026-08-23 is `v3.1.0`, released on
2026-07-29. It remains within major version `v3`; its listed breaking change is
dropping iOS 14 support. The official `v3.1.0` compose keeps this deployment's
PostgreSQL/VectorChord image and changes the Valkey digest, so the prepared
change is limited to the Immich version and Valkey image pin.

On 2026-10-12 the `v3.1.0` to `v3.3.1` update (`v3.3.1` released 2026-10-08;
no breaking changes listed in `v3.2.0`, `v3.3.0`, or `v3.3.1`) was prepared. The
official `v3.3.1` compose keeps the same PostgreSQL/VectorChord image digest
and changes the Valkey digest and health check. The gate still applies: run
and verify the backup before running the install playbook.

# Related concepts

The [Immich stack](/deployment/stack.md) defines the managed version and image
defaults. The [controller runbook](/operations/controller.md) covers local
Ansible/SSH failures that must be resolved before running the backup.

# Citations

[1] [Immich v3.1.0 release notes](https://github.com/immich-app/immich/releases/tag/v3.1.0)

[2] [Immich upgrade documentation](https://docs.immich.app/install/upgrading/)

[3] [Immich v3.1.0 Docker Compose](https://raw.githubusercontent.com/immich-app/immich/v3.1.0/docker/docker-compose.yml)
