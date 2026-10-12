---
type: Runbook
title: QuObjects HTTPS and certificate provenance
description: Live QTS and QuObjects certificate behavior, DNS, and prerequisites for verifiable S3 TLS.
tags: [qnap, quobjects, tls, dns, recovery]
timestamp: 2026-10-12T00:00:00Z
---

# Observed deployment (2026-10-12)

The intended hostname is `qnap.4jp.de`. Public DNS (`@1.1.1.1`) resolves it
to `10.10.0.6`, which belongs to the same NAS as `10.10.0.10` and the
Ansible inventory address `192.168.178.60`. The controller resolves the name;
k0s DNS, route, and trust store have not been checked because no cluster access
path was available.

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
`https://qnap.4jp.de:8010/healthcheck` failed certificate verification. No
trusted certificate was issued or installed, and no client verification bypass
was configured.

# Operational decision

Certificate replacement in QTS is NAS-wide for the QTS HTTPS administration
service and apps routed through its proxy on port 443; QuObjects port 8010
requires separate observation after a Swift restart. QTS 5.2 documents an
interactive PEM leaf/key/intermediate import or Let's Encrypt validation
through its UI, but no supported unattended DNS-01/import/renewal method was
verified. Do not automate private firmware files or QuObjects' key-bearing
mode-666 PEM. Stop before apply rather than deliver unverified S3 TLS.

The decision, read-only preview requirements, local admin recovery prerequisites,
manual interim option, and secure isolated S3/TLS alternative are recorded in
`docs/adr/0001-quobjects-https-certificate-management.md`. The local QTS admin
HTTP endpoint responded with 200 and admin SSH worked, but a GUI login and
rollback using a retained certificate/key were not rehearsed; rollback is not
ready. Never use the Kubernetes wildcard key for this service. A future renewal
must be proven on port 8010, with a no-bypass HTTPS test from the k0s network.

# Citations

[1] [QTS 5.2: replacing the server certificate](https://docs.qnap.com/operating-system/qts/5.2.x/en-us/replacing-the-server-certificate-8E7C1926.html)
[2] [QTS 5.2: downloading the server certificate](https://docs.qnap.com/operating-system/qts/5.2.x/en-us/downloading-the-server-certificate-B2D3298C.html)
