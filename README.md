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

The weekly `check-pin-freshness` CI job re-resolves each pin against its registry and compares the pinned Mailu and Traefik versions against the latest upstream releases. GitHub Actions are pinned by commit SHA; Dependabot keeps those fresh.

## Production checklist

- [ ] **DNS first**: MX to `MAILU_HOSTNAME`, matching PTR record, SPF, DMARC — and generate DKIM in the admin UI, then publish the key.
- [ ] **Strong secrets** — `SECRET_KEY` (16 hex bytes) and the initial admin password; regenerate the Traefik dashboard hash.
- [ ] **Mail-port TLS**: get certificates into the `mailu-certificates` volume before pointing clients at 465/993.
- [ ] **Back up the volumes** — `mailu-mail` (mailboxes), `mailu-data` (admin DB), and `mailu-dkim` at minimum.
- [ ] **Watch the weekly freshness run** — mail software is a favorite target; the pin-lag alarm is your patch signal.

## Testing

The [Deployment Verification](https://github.com/heyvaldemar/mailu-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml?query=branch%3Amain) workflow runs on every push, pull request, and every Monday at 06:00 UTC: actionlint, Trivy scans of the pinned images, the weekly freshness check, and a deploy-and-test job that boots all fourteen services with ephemeral credentials and requires the admin UI and webmail through Traefik plus a live SMTP banner through the TCP router.

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
