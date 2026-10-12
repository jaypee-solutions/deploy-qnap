# deploy-qnap

Ansible-Playbooks für Immich auf einer QNAP TS-673A (QTS 5.x, x86_64).

## Voraussetzungen

### Mac (Ansible-Controller)

```bash
pip install ansible
brew install 1password-cli direnv
```

### QNAP (einmalig manuell)

- **Container Station** installieren (App Center) — bringt Docker mit
- **Python3** installieren (App Center → "Python3 by QNAP") — wird von Ansible benötigt
- SSH aktivieren: Systemsteuerung → Netzwerk & Dateidienste → Telnet/SSH

## Einrichtung (einmalig)

### 1. 1Password-Item anlegen

Neues Item vom Typ *Passwort* mit dem Namen **Ansible Vault - QNAP** im Vault **Private**.
Feld `password` → beliebiges starkes Vault-Passwort.

Der `op://`-Pfad in [.vault_pass_1p.sh](.vault_pass_1p.sh) ist bereits entsprechend gesetzt.

### 2. direnv erlauben

```bash
cd deploy-qnap
direnv allow
```

### 3. vault.yml befüllen und verschlüsseln

[inventory/group_vars/qnap/vault.yml](inventory/group_vars/qnap/vault.yml) enthält das Postgres-Passwort:

```yaml
vault_db_password: "<starkes zufälliges Passwort für Postgres>"
```

```bash
# Werte eintragen, dann verschlüsseln:
ansible-vault encrypt inventory/group_vars/qnap/vault.yml
```

### 4. Immich-Version prüfen

In [roles/immich/defaults/main.yml](roles/immich/defaults/main.yml):

```yaml
immich_version: "v3.1.0"            # https://github.com/immich-app/immich/releases
immich_db_image: "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23"
```

Das korrekte `immich_db_image`-Tag steht im offiziellen
[docker-compose.yml](https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml)
des jeweiligen Releases.

### 5. Verbindung testen

```bash
ansible qnap -m ping
```

## Deployment

```bash
# Erstinstallation oder Update
ansible-playbook immich-install.yml

# On-demand Backup (Postgres-Dump)
ansible-playbook immich-backup.yml
```

Immich ist danach erreichbar unter `http://192.168.178.60:2283`.

## QuObjects HTTPS

Der separate Proxy stellt den verifizierbaren S3-Endpunkt unter
`https://qnap.4jp.de:8443` bereit. Port `8010` bleibt als direkter
QuObjects-Zugang erreichbar und trägt weiterhin das selbstsignierte
QNAP-Zertifikat; Backup-Clients dürfen ihn nicht verwenden. Die
[Proxy-Entscheidung](docs/adr/0002-quobjects-dns01-tls-proxy.md)
beschreibt DNS-01, die geprüfte lokale Weiterleitung und die Grenzen des
QNAP-Zertifikats. Die Rolle ersetzt **kein** QTS-Zertifikat. Vor **jedem**
Deployment zuerst die Vorschau prüfen und die NAS-Änderung freigeben lassen;
der SSH-Zugang kann eine biometrische Freigabe verlangen:

```bash
env -u ANSIBLE_VAULT_PASSWORD_FILE ANSIBLE_LOCAL_TEMP=/private/tmp/ansible-local \
  ansible-playbook --check --diff quobjects-proxy-install.yml
env -u ANSIBLE_VAULT_PASSWORD_FILE ANSIBLE_LOCAL_TEMP=/private/tmp/ansible-local \
  ansible-playbook quobjects-proxy-install.yml
curl https://qnap.4jp.de:8443/healthcheck
```

Nur bei Erstinstallation oder expliziter Token-Rotation liest die Rolle den
Cloudflare-DNS-01-Token über 1Password (Biometrie möglich). Der bestehende
Token bleibt auf dem NAS als `0600`-Datei für Caddys automatische Erneuerung;
mit `-e quobjects_proxy_refresh_dns_token=true` wird er nach einer Rotation
erneut aus 1Password gelesen. Da diese Rolle keine Vault-Variablen verwendet,
deaktivieren die obigen Kommandos ausschließlich den sonst automatisch
gestarteten Vault-Passwort-Helper; `ansible.cfg` bleibt unverändert. Nach jeder
Änderung SAN, Aussteller, Ablaufdatum und HTTPS ohne Zertifikats-Bypass prüfen,
auch aus dem k0s-Netz. Die Erst-Ausstellung war erfolgreich; eine spätere
automatische Erneuerung wurde noch nicht beobachtet. Bei fehlgeschlagener
Erneuerung Backup-Clients pausieren statt auf Port `8010` zurückzufallen.
Die [Proxy-Entscheidung](docs/adr/0002-quobjects-dns01-tls-proxy.md)
beschreibt Fehlerbehebung und den Rückbau ausschließlich dieses
Compose-Projekts. Die Rolle installiert keine Kubernetes-Backup-Clients.

## Backup

Der nächtliche Backup-Cron läuft um **03:00 Uhr** auf der QNAP
(`immich-install.yml` richtet ihn ein) und schreibt komprimierte SQL-Dumps nach
`/share/Container/immich/backups/`. Dateien älter als 7 Tage werden automatisch gelöscht.

Manuell auslösen:

```bash
ansible-playbook immich-backup.yml
```

## Update

Versionsnummer in `roles/immich/defaults/main.yml` aktualisieren,
ggf. `immich_db_image` anpassen, dann:

```bash
ansible-playbook immich-install.yml
```

## Projektstruktur

```text
deploy-qnap/
├── ansible.cfg                          # Ansible-Konfiguration (pipelining, SSH-Optionen)
├── .envrc                               # direnv: setzt ANSIBLE_VAULT_PASSWORD_FILE
├── .vault_pass_1p.sh                    # liest Vault-Passwort aus 1Password
├── immich-install.yml                   # Playbook: Install / Update
├── immich-backup.yml                    # Playbook: On-demand Backup
├── inventory/
│   ├── hosts.ini
│   └── group_vars/qnap/
│       ├── vars.yml                     # Verbindungs- und Pfadvariablen
│       └── vault.yml                    # verschlüsselte Secrets
└── roles/immich/
    ├── defaults/main.yml                # Immich-Version, Image-Tags, Pfade
    ├── handlers/main.yml
    ├── tasks/
    │   ├── install.yml
    │   └── cron.yml
    └── templates/
        ├── docker-compose.yml.j2
        ├── immich.env.j2
        └── immich-backup.sh.j2
```

## QNAP-Besonderheiten

- **SSH-Shell**: Die interaktive QNAP-CLI wird durch `-o RequestTTY=no` in `ansible.cfg`
  umgangen — Ansible bekommt eine normale Shell ohne TTY.
- **Python**: Installiert via App Center ("Python3 by QNAP"),
  Pfad: `/share/CACHEDEV1_DATA/.qpkg/Python3/opt/python3/bin/python3`
- **Docker**: Container Station 3.x, Binary unter `/usr/local/bin/docker`
