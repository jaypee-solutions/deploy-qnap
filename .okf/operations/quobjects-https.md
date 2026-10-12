---
type: Runbook
title: QuObjects HTTPS and certificate provenance
description: Live QTS and QuObjects certificate behavior, DNS, and prerequisites for verifiable S3 TLS.
tags: [qnap, quobjects, tls, dns, recovery]
timestamp: 2026-10-12T00:00:00Z
---

# Observed deployment (2026-10-12)

The intended hostname is `qnap.4jp.de`. Public DNS (`@1.1.1.1`) now resolves
it to `10.10.0.10`, an address of the NAS in the Ansible inventory at
`192.168.178.60`. It previously resolved to another NAS interface,
`10.10.0.6`. The controller resolves the updated name; k0s DNS, route, and
trust store have not been checked because no cluster access path was available.

The NAS runs QTS 5.2.10 build 20260731 and QuObjects' `OSS` package 2.5.869.
QTS stunnel on port 443 uses `/etc/stunnel/stunnel.pem` (mode `600`). The
QuObjects Swift proxy listens on port 8010; its `proxy-server.conf` sets both
`cert_file` and `key_file` to `/etc/swift/cert.pem`. The packaged `swift.sh`
concatenates the QTS stunnel PEM and optional CA PEM into this **separate**
Swift file during service startup. The observed Swift file has mode `666` and
contains a private key. Changes to QTS's certificate cannot be assumed to
refresh the already-running QuObjects service, and restarts may reintroduce
insecure key permissions.

At inspection, both HTTPS ports presented a self-signed `CN=QNAP NAS` leaf
without a DNS SAN; issuer is the same self-signed QNAP NAS. The leaf expires
2031-09-14. A normal request to
`https://qnap.4jp.de:8010/healthcheck` failed certificate verification.
No client verification bypass was configured; port 8010 remains unsuitable
as a direct S3 backup endpoint.

# Operational decisions

QTS certificate replacement is NAS-wide for HTTPS administration and apps
routed through its proxy on port 443. QuObjects port 8010 reads a separate
copy at service startup. QTS 5.2 documents interactive PEM import but no
supported unattended DNS-01/import/renewal method was verified; see
`docs/adr/0001-quobjects-https-certificate-management.md`. Do not automate
private firmware files or QuObjects' key-bearing mode-666 PEM.

The additive proxy in `quobjects-proxy-install.yml` is specified by
`docs/adr/0002-quobjects-dns01-tls-proxy.md`: Caddy listens on
`10.10.0.10:8443`, uses a scoped Cloudflare DNS API token from 1Password for
automatically renewed DNS-01 TLS, and stores its certificate/key separately
from QTS. HAProxy listens only on `127.0.0.1:18010` and validates the
QuObjects backend certificate chain over TLS against the approved public
self-signed leaf (SHA-256 fingerprint starts `5D:39:98:B8`). No hostname
verification is possible for the SAN-less backend certificate; a Caddy-only
probe using a trust pool returned HTTP 502 with a legacy-CN verification
error. A local hardened HAProxy smoke request returned HTTP 200 with the
approved leaf and HTTP 503 with an unrelated trust anchor.

The first NAS build restarted Caddy before it could bind a port: the upstream
Caddy image carries a low-port file capability, which conflicts with
`cap_drop: ALL` and `no-new-privileges`. The custom image removes it for port
8443. Ansible's atomic template replacement also left a running container
with a stale bind-mounted Caddyfile; the role now recreates the proxy
containers when mounted files change. A one-time remount can be previewed
with `-e quobjects_proxy_force_recreate=true`.

The private DNS token remains on the NAS in a mode-`0600` file for renewal;
the role reads 1Password only on first install or an explicit token refresh,
not on every replay. Unsetting `ANSIBLE_VAULT_PASSWORD_FILE` for this
proxy-only playbook avoids invoking Immich's unrelated Vault-password helper.
The vendor's mode-`666` QuObjects private-key file remains a separate
unresolved risk. Existing QTS/QuObjects listeners are not reconfigured.

# Live verification (2026-10-12)

The controller reached `https://qnap.4jp.de:8443/healthcheck` with HTTP 200
and TLS verification result 0. `openssl s_client` verified the trusted chain
and hostname. The observed leaf SAN is `DNS:qnap.4jp.de`; issuer is Let's
Encrypt `YE2`, valid from 2026-10-12 15:43:51 UTC to 2027-01-10 15:43:50
UTC. Caddy reported successful issuance and certificate maintenance startup;
its persisted leaf/key and NAS DNS token file are mode `0600` under a mode
`0700` directory. The automatic renewal mechanism is configured but its
first future renewal has not yet occurred. No k0s path or authenticated S3
operation was exercised, and the proxy-only rollback was not rehearsed.

Before each NAS apply, inspect Ansible `--check --diff`, then verify the
new port 8443 without certificate bypass from the controller and a k0s path.
Stop backups instead of falling back to port 8010 if issuance or renewal
fails. The original admin recovery path at `http://192.168.178.60:8080/`
responded with 200 and admin SSH worked, but a GUI login was not rehearsed.
No Kubernetes backup client belongs in this repository.

# Citations

[1] [QTS 5.2: replacing the server certificate](https://docs.qnap.com/operating-system/qts/5.2.x/en-us/replacing-the-server-certificate-8E7C1926.html)
[2] [QTS 5.2: downloading the server certificate](https://docs.qnap.com/operating-system/qts/5.2.x/en-us/downloading-the-server-certificate-B2D3298C.html)
