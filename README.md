# Mailu + Traefik + Let's Encrypt — Docker Compose

[![Deployment Verification](https://github.com/heyvaldemar/mailu-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml/badge.svg?branch=main)](https://github.com/heyvaldemar/mailu-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This repository deploys a full **Mailu** mail server — SMTP (postfix), IMAP (dovecot), spam filtering (rspamd), antivirus (ClamAV), webmail (Roundcube), CalDAV/CardDAV (Radicale), admin UI — behind **Traefik**: HTTPS for the web hostnames via **Let's Encrypt**, raw TCP passthrough for the mail ports.

## Getting started

Running a mail server is the deep end of self-hosting: you need forward and reverse DNS, MX/SPF/DKIM/DMARC records, and a hosting provider that allows outbound port 25. Read the [Mailu docs](https://mailu.io/2024.06/) alongside this template.

```bash
# 1. Clone
git clone https://github.com/heyvaldemar/mailu-traefik-letsencrypt-docker-compose
cd mailu-traefik-letsencrypt-docker-compose

# 2. Create the external Docker network (the rest are created by compose)
docker network create traefik-network

# 3. Copy the environment template and fill it in — this file is BOTH the
#    compose variables and the Mailu application config (env_file)
cp .env.example .env
$EDITOR .env

# 4. Deploy
docker compose -f mailu-traefik-letsencrypt-docker-compose.yml -p mailu up -d
```

First start takes a few minutes (rspamd and ClamAV load their databases; the admin container waits for the DNSSEC-validating resolver). Then `https://${MAILU_HOSTNAME}/admin` accepts the initial admin account from `.env`.

### What success looks like

```bash
docker compose -f mailu-traefik-letsencrypt-docker-compose.yml -p mailu ps
curl -fskL -o /dev/null -w "%{http_code}\n" "https://${MAILU_HOSTNAME}/admin/"    # 200
printf "" | nc -w5 YOUR_SERVER 25   # 220 banner
```

### Common first-deploy issues

- **admin restarts complaining about the DNS resolver.** The stack ships its own unbound resolver because Mailu requires DNSSEC validation — if your host firewall blocks outbound DNS (udp/53) the whole stack stays down. Fix the network, not the container.
- **Mail clients can't connect over TLS (465/993/995).** Traefik passes those ports through as raw TCP; the `front` container serves TLS itself from the `mailu-certificates` volume (`TLS_FLAVOR=mail`). Export Traefik's certificates with a certs-dumper or mount your own `cert.pem`/`key.pem` there.
- **Outbound mail bounces or times out.** Your provider filters port 25 — request unblocking or use a relay (`RELAYHOST`).
- **`docker compose up` fails with `set in .env`.** A required variable is empty; the error names it.

## Supply chain trust

Fourteen images — the Mailu 2024.06.58 set from ghcr.io, [`clamav/clamav-debian`](https://hub.docker.com/r/clamav/clamav-debian), [`apache/tika`](https://hub.docker.com/r/apache/tika), [`redis`](https://hub.docker.com/_/redis), [`traefik`](https://hub.docker.com/_/traefik) — pinned to `tag@sha256:<digest>` as interpolation defaults in the compose `x-images` block. `git pull` alone delivers the tested combination; an `*_IMAGE_TAG` variable in `.env` overrides deliberately.

The daily `check-pin-freshness` CI job re-resolves each pin against its registry and compares the pinned Mailu and Traefik versions against the latest upstream releases. GitHub Actions are pinned by commit SHA; Dependabot keeps those fresh.

## Production checklist

- [ ] **DNS first**: MX to `MAILU_HOSTNAME`, matching PTR record, SPF, DMARC — and generate DKIM in the admin UI, then publish the key.
- [ ] **Strong secrets** — `SECRET_KEY` (16 hex bytes) and the initial admin password; regenerate the Traefik dashboard hash.
- [ ] **Mail-port TLS**: get certificates into the `mailu-certificates` volume before pointing clients at 465/993.
- [ ] **Back up the volumes** — `mailu-mail` (mailboxes), `mailu-data` (admin DB), and `mailu-dkim` at minimum.
- [ ] **Watch the weekly freshness run** — mail software is a favorite target; the pin-lag alarm is your patch signal.

## Unattended updates

Releases are the update channel: a tag is cut only after CI has built the pinned images, booted the full stack, and passed the smoke tests. `update.sh` moves a deployment to the newest tag and nothing else:

```bash
./update.sh --dry-run   # show what would be applied
./update.sh             # update within the current major and redeploy
```

Put it on a timer for hands-off minor/patch updates:

```bash
# crontab -e
17 5 * * *  /opt/mailu-traefik-letsencrypt-docker-compose/update.sh >> /var/log/mailu-update.log 2>&1
```

The script refuses to cross a MAJOR template version on its own — majors are breaking by definition and their release notes exist to be read. After reading them, `./update.sh --allow-major` performs the jump. It also refuses to touch a checkout with local modifications: your customization belongs in `.env`, which updates never overwrite.

This is deliberately a host-side script and not a container in the stack: an in-stack updater needs the Docker socket (root on the host) and turns "someone pushed to a repo" into "someone deployed to your machine" with no operator in the loop. A cron job under your own user updates only to tagged, CI-verified states and leaves the trust boundary where it was.

## Resource limits

Every service carries memory and CPU limits plus reservations as compose-level defaults — the same values CI boots the stack under. Override any of them in `.env` (the knobs and their defaults are listed in `.env.example`, e.g. `TRAEFIK_MEMORY_LIMIT=512m`) and the override survives every `git pull`. If a service is OOM-killed under real load, `docker inspect <container> --format '{{.State.OOMKilled}}'` says so; raise its `_MEMORY_LIMIT` and recreate.

## Backups

The `backups` container runs on a loop: an initial delay (`MAILU_BACKUP_INIT_SLEEP`, default 30m), then every `MAILU_BACKUP_INTERVAL` (default 24h) it takes a consistent copy of each SQLite database (`main.db`) through Python's `sqlite3` backup API - no application stop - and a `tar.gz` of the rest of the data directory (live database files excluded), into the `mailu-backups` volume; files older than `MAILU_BACKUP_PRUNE_DAYS` (default 7) are pruned. Each artefact logs `... backup OK: <file> (<bytes> bytes)` or `FAILED` (kept as `<file>.failed`) — grep the log for `FAILED` from your monitoring.

**Verify backups are running:**

```bash
docker compose -p mailu logs backups | tail -5
docker compose -p mailu exec backups ls -la /srv/mailu/backups/
```

**Restore** a backup set with the interactive script (`chmod +x mailu-restore-data.sh` once): it stops mailu, unpacks the data archive over the data directory, restores each database from its consistent copy, and starts mailu again.

```bash
./mailu-restore-data.sh
```

**Off-host replication.** Backups live in a named volume on the same host — bind-mount `MAILU_BACKUPS_PATH` to a directory covered by your off-host backup solution (restic, rclone, Borg, S3 sync).

## Container hardening

Every service runs with `security_opt: no-new-privileges:true`, so a process cannot gain privileges through setuid binaries even if it escapes its initial capability set. Infrastructure containers (the reverse proxy, databases, caches, backups) run with `cap_drop: [ALL]` and add back only what their entrypoints need: `NET_BIND_SERVICE` for Traefik to bind :80/:443, `CHOWN`/`SETUID`/`SETGID` (and friends) for database images to own their data directory and drop to their service user. Application containers keep the default capability set on purpose: upstream images assume it, and a wrong guess there is a boot loop in production rather than a hardening win. CI boots the stack under exactly these settings on every push, so what ships is what was tested.

## Testing

The [Deployment Verification](https://github.com/heyvaldemar/mailu-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml?query=branch%3Amain) workflow runs on every push, pull request, and every day at 06:00 UTC: actionlint, Trivy scans of the pinned images, the weekly freshness check, and a deploy-and-test job that boots all fourteen services with ephemeral credentials and requires the admin UI and webmail through Traefik plus a live SMTP banner through the TCP router.

### Backup and restore, proven

`tests/e2e-backup-restore.sh` runs against the live stack and is what CI executes after the smoke test. The scenario that matters most is the restore roundtrip: the application is stopped, the baseline database copy is put back, and a row inserted after the baseline is gone. The tests stop the application briefly and write into its data directory — run them on a staging copy with short intervals in `.env` (`MAILU_BACKUP_INIT_SLEEP=15s`, `MAILU_BACKUP_INTERVAL=60s`), never on production.

```bash
chmod +x tests/e2e-backup-restore.sh
./tests/e2e-backup-restore.sh
```

## Security Notes

- Credentials are read from `.env` at deploy time; `.env` is gitignored and compose fails fast on missing required variables.
- **Pre-rotation advisory.** Releases before v1.0.0 (2026-09-01) tracked a `.env` with a real `SECRET_KEY`. Rotate it if your deployment reused it — sessions and signed tokens are invalidated, mailboxes are untouched.
- The oletools and tika helper networks are `internal: true`; only `front` and Traefik face the outside.

---

## About the maintainer

<div align="center">

**Maintained by [Vladimir Mikhalev](https://github.com/heyvaldemar)** — Docker Captain · IBM Champion · AWS Community Builder

[YouTube](https://www.youtube.com/channel/UCf85kQ0u1sYTTTyKVpxrlyQ?sub_confirmation=1) · [Blog](https://heyvaldemar.com) · [LinkedIn](https://www.linkedin.com/in/heyvaldemar/)

</div>
