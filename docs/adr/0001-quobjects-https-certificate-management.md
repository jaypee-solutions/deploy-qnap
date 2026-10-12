# ADR 0001: Do not automate QTS certificate replacement without a supported import path

- Status: Blocked pending a safe installation/renewal mechanism
- Date: 2026-10-12

## Context

The intended QuObjects S3 name is `qnap.4jp.de`. Public DNS returns the private
address `10.10.0.6`, which is an interface on the NAS; its `10.10.0.10` address
also serves QuObjects on port 8010. DNS and routing from k0s have **not** been
verified because no cluster access path is available.

Read-only inspection of QTS 5.2.10 (build 20260731) and the QuObjects package
(`OSS` 2.5.869) established the actual certificate path:

- QTS stunnel serves HTTPS on port 443 using `/etc/stunnel/stunnel.pem`.
- QuObjects' Swift proxy serves HTTPS on port 8010 with both `cert_file` and
  `key_file` set to `/etc/swift/cert.pem`. Its packaged `swift.sh` copies the
  QTS stunnel PEM and optional `/etc/stunnel/uca.pem` into this separate file
  **when Swift starts**. Importing a QTS certificate is not proof that the
  running Swift workers have reloaded it.
- The live Swift PEM contains the private key and has mode `666`, whereas the
  QTS stunnel PEM is mode `600`. Do not copy a newly issued key into this path
  without resolving the package's key-permission behavior, including restarts
  and package updates. Never export or reuse the Kubernetes wildcard key.
- The currently presented certificate is self-signed (`CN=QNAP NAS`), has no
  SAN, and expires 2031-09-14. A normal HTTPS request to
  `https://qnap.4jp.de:8010/healthcheck` fails certificate verification.

[QTS 5.2's documented server-certificate replacement][import] is an
interactive, NAS-wide **Import certificate** (leaf, matching PEM private key,
intermediate certificate) or QTS-managed Let's Encrypt flow recommending
ports 80/443 for validation. We found no documented, supported unattended
DNS-01 issuance/import and renewal interface for this QTS version. Replacing
QTS's certificate by editing private firmware files or reverse-engineering its
web CGI would bypass its validation and recovery path.

## Decision

**Stop before issuance, import, restart, or renewal automation.** Do not build
an unsupported QTS-certificate writer, modify the Swift PEM in place, or
configure S3 clients to disable TLS verification. No certificate was replaced
and no renewal job was installed. A renewed certificate must be proven to be
served by **port 8010**, not inferred from QTS's port 443.

A supported, isolated TLS/S3 endpoint with DNS-01 and verified upstream
identity is the preferred automation alternative if QNAP cannot provide a safe
certificate deployment path. Its port, routing, trust boundary, and certificate
permissions need a separate design and approval; it is not an implicit
fallback and is not deployed by this ADR. A manual QTS import of a *dedicated*
DNS-01-issued certificate for `qnap.4jp.de` is an interim option only after the
Swift key-permission issue and recovery prerequisites below are addressed; it
is **not** automated renewal.

## Preview and recovery gate before any future apply

1. Preview the issuer, SAN, validity, full chain, and public-key match of the
   proposed dedicated leaf/key; inspect the current QTS and QuObjects served
   certificates and DNS from both the controller and k0s. Do not print keys or
   tokens. The QTS UI has no documented transactional dry-run: do not click
   **Apply** until this read-only preview and the NAS-wide impact are reviewed
   with the owner.
2. Inventory consumers of QTS HTTPS on port 443 (administration and any apps
   served through QTS's web proxy); QuObjects on port 8010 must be checked and
   restarted separately if needed. Ensure every other HTTPS hostname clients
   use is covered by the proposed certificate or plan its migration. The
   observed QTS local administration path `http://192.168.178.60:8080/`
   responded with HTTP 200 and admin SSH was reachable; an actual local GUI
   login and rollback have **not** been rehearsed.
3. Before applying, arrange a local admin login independent of HTTPS, retain
   the previous QTS certificate/key and any chain through the [QTS download
   procedure][download] in secure storage outside this repository, and verify
   that the operator can restore them or the default certificate if HTTPS login
   breaks. QTS warns that invalid PEM material can prevent HTTPS login.
   Confirm how to repair Swift's private-key file permissions persistently.
   **Rollback is not ready today:** no prior key/chain was exported, no admin
   GUI login was exercised, and the key-permission issue remains open.
4. Obtain explicit approval for the NAS-wide change. Use QTS Control Panel →
   System → Security → SSL Certificate & Private Key → Server Certificate →
   Replace Certificate → Import certificate, supplying the dedicated matching
   PEM certificate, key, and intermediate. Do not expose any secret in logs or
   a playbook. Coordinate any Swift restart with S3 users, then verify both
   443 and 8010 present the expected SAN, issuer, chain, and expiry. Test
   `https://qnap.4jp.de:8010/healthcheck` without `-k` or `--insecure`
   from the controller **and** a k0s-representative host.
5. If an import or subsequent renewal fails, stop using QuObjects for backups;
   reach the NAS by the preverified local admin path, reimport the retained
   certificate/key/chain or restore QTS's default security certificate, and
   check both HTTPS ports again. Recheck Swift after every restart or QTS/OSS
   update. Do not regard a port-443 success as proof of port-8010 recovery.
   Set a renewal schedule and monitor expiry only after a supported mechanism
   and successful end-to-end rehearsal exist.

[import]: https://docs.qnap.com/operating-system/qts/5.2.x/en-us/replacing-the-server-certificate-8E7C1926.html
[download]: https://docs.qnap.com/operating-system/qts/5.2.x/en-us/downloading-the-server-certificate-B2D3298C.html
