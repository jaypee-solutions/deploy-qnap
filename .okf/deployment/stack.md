---
type: Deployment
title: Immich stack on QNAP
description: Ansible deploys an Immich server, machine-learning service, Valkey, and PostgreSQL stack on the QNAP.
tags: [immich, qnap, ansible, docker-compose]
timestamp: 2026-11-27T12:00:00+01:00
---

# Overview

The `immich` role imported by [immich-install.yml](/immich-install.yml)
manages the Immich stack on the host in [inventory/hosts.ini](/inventory/hosts.ini).
The intended target is a QNAP TS-673A running QTS 5.x on x86_64.

The compose template defines these containers:

| Service | Container | Purpose |
|---|---|---|
| `immich-server` | `immich_server` | Web/API server, exposed on port `2283`. |
| `immich-machine-learning` | `immich_machine_learning` | Machine-learning workloads with a persistent model cache. |
| `redis` | `immich_valkey` | Valkey service used by Immich. |
| `database` | `immich_postgres` | PostgreSQL database with the Immich VectorChord/pgvectors image. |

The role owns the stack directory, upload directory, backup directory,
compose file, `.env`, backup script, and nightly cron entry. The default paths
are `/share/Container/immich`, `/share/Immich`, and
`/share/Container/immich/backups`.

# Configuration

The current defaults target Immich `v3.4.2` with pinned database and Valkey
image digests in [roles/immich/defaults/main.yml](/roles/immich/defaults/main.yml).
The official `v3.4.2` compose keeps the PostgreSQL/VectorChord image
(`14-vectorchord0.4.3-pgvectors0.2.0`, same digest since `v3.1.0`) and uses Valkey
digest `sha256:418652cfb58ef879d4978c33553735d7147016032d5aefaa14c828e611eb9dfd`.
Its Valkey health check requires a `PONG` reply, which the role template mirrors.
The machine-learning service sets `MACHINE_LEARNING_MODEL_REVISION` from
`immich_ml_model_revision` (default `v2`, as in the official compose); see
`docs/adr/0004-immich-ml-model-revision-v2.md` for rationale, the
open upstream issue [#33380](https://github.com/immich-app/immich/issues/33380)
(null face embeddings), and the `main` rollback.
The database credentials come from the encrypted
[vault variables](/inventory/group_vars/qnap/vault.yml); they must never be
placed in this bundle.

The role first discovers `docker` on the QNAP and otherwise uses the configured
Container Station path. It pulls images and runs `docker compose up -d
--remove-orphans`; a handler restarts the stack when managed templates change.

# Related concepts

Operational safety is defined by the [upgrade gate](/operations/upgrade-gate.md)
and the [backup workflow](/deployment/backup.md).

# Citations

[1] [Immich v3.4.2 Docker Compose](https://raw.githubusercontent.com/immich-app/immich/v3.4.2/docker/docker-compose.yml)
