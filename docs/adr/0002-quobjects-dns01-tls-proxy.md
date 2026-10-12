# ADR 0002: Renew QuObjects-facing TLS through a NAS-local DNS-01 proxy

- Status: Accepted and deployed on 2026-10-12; k0s path and first renewal unverified
- Date: 2026-10-12

## Decision

Keep [QTS certificate management](0001-quobjects-https-certificate-management.md)
unchanged. Expose a **new** S3 endpoint at `https://qnap.4jp.de:8443` on
`10.10.0.10`; do not send backup clients directly to port 8010. The name now
resolves to `10.10.0.10` from the controller and Cloudflare DNS. Kubernetes
resolution and routing still require a cluster-side check.

An Ansible-managed Docker Compose stack on the NAS runs two purpose-specific
processes in host network mode:

1. Caddy binds only `10.10.0.10:8443`. Its pinned-version Cloudflare DNS
   module obtains a **dedicated** publicly trusted certificate for
   `qnap.4jp.de` through DNS-01 and automatically renews it into persistent
   private storage. Neither public inbound port 80 nor a QTS certificate
   change is needed. The role reads a scoped Cloudflare API token from its
   1Password reference on the controller and installs a `0600` runtime
   environment file under a `0700` NAS directory. The token and the proxy's
   private key never enter Git or the Kubernetes wildcard-key store.
2. HAProxy binds only `127.0.0.1:18010` and forwards HTTP requests to
   `127.0.0.1:8010` **over TLS**. Its `verify required` trust store contains
   the currently reviewed, self-signed QuObjects *public* leaf alone. The role
   compares its SHA-256 fingerprint with the approved fingerprint before
   writing the public PEM. This pins a private trust anchor for chain
   verification, not the exact leaf on every handshake: certificates
   unrelated to that trust anchor fail closed. The QuObjects leaf has no SAN,
   so backend hostname verification is unavailable until the vendor fixes its
   certificate. This loopback-only compromise does not make QuObjects'
   certificate publicly trusted. A local test rejected an unrelated trust
   anchor with HTTP 503.

Caddy and HAProxy preserve the original HTTP Host header (including `:8443`)
and URI for S3 request signatures. S3 clients must use path-style addressing
unless separate bucket hostnames and certificates are intentionally added.
Port 8010 still presents QNAP's old certificate and **must not** be used as a
verified backup endpoint. Restrict direct access to it at the network policy
boundary after proving that QuObjects administration does not depend on it.

## Tradeoffs and safeguards

- The upstream certificate's key currently resides in a vendor-managed
  mode-`666` file. Although this proxy does not distribute that key or bypass
  TLS certificate-chain verification, another local user with access to the
  key could impersonate the backend. Correcting the vendor behavior or using
  a service with a properly protected backend identity remains necessary for
  stronger end-to-end assurance. A QTS/QuObjects restart can change the
  upstream leaf; a certificate outside the pinned trust chain then fails
  closed until the new identity is inspected and approved.
- Caddy handles ACME renewal automatically, but the first future renewal has
  not yet occurred. Keep `/data` and `/config` persistent across container
  replacement; monitor certificate expiry and renewal errors without logging
  token or key material.
- The scoped DNS token is resident on the NAS so renewal continues without
  the controller. NAS administrators and Docker administrators can read its
  environment. The role fetches it from 1Password only on first install or
  with `-e quobjects_proxy_refresh_dns_token=true` after rotation; ordinary
  redeployments reuse the existing mode-`0600` file.
- Host networking avoids an externally reachable plaintext Docker port:
  Caddy listens only on the chosen NAS address, and HAProxy only on loopback.
  No QuObjects package file, QTS server certificate, or existing Immich
  container is modified.

## Deployment evidence (2026-10-12)

After per-apply check-mode previews and operator approval, both proxy
containers were running. The controller's no-bypass HTTPS health check
returned HTTP 200 at `10.10.0.10:8443`; `openssl s_client` verified the public
chain and `qnap.4jp.de` peer name. The observed leaf has SAN
`DNS:qnap.4jp.de`, issuer **Let's Encrypt YE2**, and validity
**2026-10-12 15:43:51 UTC to 2027-01-10 15:43:50 UTC**. Caddy logged
successful issuance and active certificate maintenance. Its persistent
certificate and private-key files and the NAS DNS token file are mode `0600`
under a mode-`0700` directory. This confirms DNS-01 issuance and storage,
**not** a completed future renewal. No authenticated S3 operation or
k0s-originated TLS test was possible without client credentials or cluster
access. A rollback procedure is documented but has not been rehearsed.

Two rollout issues shaped the managed design: the stock Caddy binary carries
a low-port file capability, which conflicts with the intentionally
capability-free container; the custom image removes it for port 8443.
Ansible's atomic replacement of a bind-mounted Caddyfile left a running
container on the old inode; the role now recreates this Compose project when
mounted files change. An operator can request a one-time remount with
`-e quobjects_proxy_force_recreate=true`, after previewing that apply.

## Preview, deployment and rollback

Before **each** apply, run `ansible-playbook --check --diff
quobjects-proxy-install.yml` with the repository's Ansible configuration and
inspect the proposed paths, interface/port and approved upstream fingerprint.
This proxy role does not consume Ansible Vault variables: if the unrelated
Vault-password helper prompts or times out, unset `ANSIBLE_VAULT_PASSWORD_FILE`
for this playbook only. Initial installation and explicit token refresh read
the 1Password item (biometric approval may be requested); secret task output
is masked. Inspect the issuer/SAN/chain after ACME issuance; no private key
or token belongs in logs or a PR. Review the NAS-side port availability and
confirm that local admin SSH/HTTP on `192.168.178.60` remain available; no
NAS-wide certificate import is planned. Obtain explicit approval before
running the apply command.

After deployment, verify `https://qnap.4jp.de:8443/healthcheck` **without**
`-k` or `--insecure` from the controller and a k0s-representative host, inspect
its issuer/SAN/expiry, and check that the HAProxy backend has not reported
certificate failures. Test an authenticated S3 request through `:8443` before
configuring production backups; no backup client is deployed by this repo.

If import/issuance or renewal fails, stop using the new endpoint for backups.
Inspect Caddy's ACME and HAProxy errors without printing secrets; check DNS
challenge permissions and the pinned upstream fingerprint. On deployment
failure or rollback, stop **only** this Compose project using
`/share/CACHEDEV1_DATA/.qpkg/container-station/bin/docker compose -f
/share/Container/quobjects-proxy/docker-compose.yml down` on the NAS after
an operator review. The original QTS and QuObjects listeners remain
available unchanged; do not fall back to unverified port 8010. Retain
private Caddy storage until rollback is complete and a replacement backup
endpoint is verified.

## References

- [Caddy automatic HTTPS and DNS challenge](https://caddyserver.com/docs/automatic-https)
- [Caddy Cloudflare module and token permissions](https://github.com/caddy-dns/cloudflare)
- [HAProxy 3.2 configuration manual](https://docs.haproxy.org/3.2/configuration.html)
