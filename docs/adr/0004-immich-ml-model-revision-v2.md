# ADR 0004: Use ML model revision v2

- Status: Accepted
- Date: 2026-11-27

## Decision

Follow the official Immich `v3.4.2` compose and set
`MACHINE_LEARNING_MODEL_REVISION=v2` on the `immich-machine-learning` service.
The value comes from the role default `immich_ml_model_revision`.

Why:

- The official compose sets it since upstream PR #32289; the documented
  default is `main`, `v2` selects newer model exports.
- `v2` fixes language-specific OCR recognition models (#32512).
- A reported comparison of `main` and `v2` embeddings shows cosine similarity
  of about 0.9999, so no CLIP/face re-index is needed.

## Consequences

- New model files download into the `model_cache` volume: extra disk use and
  slower first machine-learning jobs.
- Open upstream issue immich-app/immich#33380: with `v2`, face recognition can
  emit null embeddings, causing PostgreSQL errors
  `invalid input syntax for type vector`. Detection: that string in the
  `immich_postgres` logs.
- Rollback: set `immich_ml_model_revision: "main"` (group_vars or role
  default) and re-run `immich-install.yml`.
