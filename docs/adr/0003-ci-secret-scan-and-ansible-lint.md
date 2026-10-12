# ADR 0003: Gate pull requests with TruffleHog and ansible-lint

- Status: Accepted
- Date: 2026-10-12

## Decision

Two GitHub Actions workflows run on every pull request and on pushes to `main`:

- `trufflehog.yml` scans the commit range with `--results=verified,unknown`
  and fails on findings. Full history is fetched so the range resolves.
- `ansible-lint.yml` runs `ansible-lint` with the default (`production`
  profile) rules.

Third-party actions are pinned to commit SHAs with the release tag in a comment.
Workflows have read-only `contents` permission and cancel superseded runs.
TruffleHog's CLI version is pinned explicitly instead of `latest`.

## Lint baseline

The repository had 28 pre-existing `ansible-lint` violations. Fixing them
(for example adding `changed_when` or replacing `shell` with `command`) changes
behavior of tasks that run against a real NAS and was out of scope. The existing
violations are recorded per file and rule in `.ansible-lint-ignore`, so CI
passes today while any new violation fails. Entries should be removed as the
underlying code is fixed; the file must not be regenerated to hide new findings.

## Consequences

- Action SHAs and the TruffleHog version go stale and need deliberate updates.
- `unknown` results include unverifiable matches, which can produce false
  positives; resolve them by rotating the credential or, if truly benign, with
  a documented TruffleHog exclusion.
- CI cannot decrypt `inventory/group_vars/qnap/vault.yml`; linting does not
  require it, and no vault password is provided to GitHub.
