---
okf_version: "0.1"
---

# deploy-qnap Knowledge Bundle

This bundle documents the Ansible-managed Immich deployment and its operational
guardrails. Read the concepts below before changing deployment or upgrade
behavior.

# Deployment

* [Immich stack](deployment/stack.md) - Ansible role, services, paths, and pinned image configuration.
* [Backup workflow](deployment/backup.md) - On-demand and scheduled PostgreSQL backup behavior.

# Operations

* [Ansible controller](operations/controller.md) - macOS/Linux controller settings and QNAP SSH quirks.
* [Upgrade gate](operations/upgrade-gate.md) - Evidence required before an Immich version upgrade.
