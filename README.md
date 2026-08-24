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
immich_version: "v1.132.3"          # https://github.com/immich-app/immich/releases
immich_db_image: "ghcr.io/immich-app/postgres:14-vectorchord0.3.0-pgvectors0.2.0"
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
