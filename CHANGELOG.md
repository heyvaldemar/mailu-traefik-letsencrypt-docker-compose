# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_(no unreleased changes yet)_

## [1.3.0] - 2026-09-02

### Added

- **A `backups` service** for the admin database (users, domains, aliases), the DKIM keys and every mailbox: on a loop it takes a consistent copy of each SQLite database (`main.db`) through Python's `sqlite3` backup API - no application stop - and a `tar.gz` of the rest of the data directory (live database files excluded), logs `OK` or `FAILED` per artefact (a failed archive is kept as `.failed`), and prunes only its own files. Schedule knobs (`MAILU_BACKUP_INIT_SLEEP`, `MAILU_BACKUP_INTERVAL`, `MAILU_BACKUP_PRUNE_DAYS`, path and names) have defaults listed in `.env.example`.
- **`mailu-restore-data.sh`** — interactive restore of a backup set: stops mailu, unpacks the data archive, restores each database copy, starts mailu.
- CI waits for the first backup cycle and proves the archives are readable and the database copy passes `PRAGMA integrity_check`.

## [1.2.0] - 2026-09-02

### Added

- **Resource limits on every service, as `.env`-overridable defaults.**
  Each service now carries memory and CPU limits plus reservations
  (`<SERVICE>_MEMORY_LIMIT`, `_CPU_LIMIT`, `_MEMORY_RESERVATION`,
  `_CPU_RESERVATION`, defaults listed in `.env.example`). Set any of
  them in `.env` and the override survives every `git pull`. The
  defaults are what CI boots the stack under, so they are known to be
  enough for a fresh install; raise a limit if a service is OOM-killed
  under your real load (`docker inspect` shows `OOMKilled=true`).

## [1.1.0] - 2026-09-02

### Added

- **`update.sh`** — unattended updates to the newest tagged release,
  and nothing else: a tag is cut only after CI has booted the pinned
  images and passed the smoke tests, so "update to the latest tag" means
  "update to a combination a machine has already run". It refuses to
  cross a major version on its own (`--allow-major` after reading the
  notes), refuses a checkout with local modifications, and supports
  `--dry-run`. Put it on a cron timer for hands-off minor/patch updates.

## [1.0.0] - 2026-09-01

First semver release. Brings this template to the fleet standard established
in [keycloak-traefik-letsencrypt-docker-compose](https://github.com/heyvaldemar/keycloak-traefik-letsencrypt-docker-compose)
v1.2.0.

### Fixed (the template was undeployable as published)

- **The entire Mailu configuration lived in an untracked `.env`** that
  every service loads via `env_file:` — a fresh clone could not start at
  all, and the README documented almost none of it. `.env.example` now
  carries the full contract: Traefik settings, the three routed
  hostnames, and the Mailu application config (SECRET_KEY, DOMAIN,
  HOSTNAMES, TLS_FLAVOR, the initial admin account, and the commonly
  tuned options).
- The tracked `.env` also carried a real `SECRET_KEY` — rotate it if
  your deployment reused it (rotating invalidates sessions and signed
  tokens, not mailboxes).

### Fixed (found by the new CI)

- **fetchmail shared the admin database volume.** fetchmail runs as its
  own user (uid 101) and chowns its data directory at startup — on a
  shared volume that clobbered the ownership the admin container needs,
  and admin died on `/data/instance` with every fresh deployment.
  fetchmail now has its own volume, matching upstream Mailu's layout.
- **Fresh named volumes were unusable by the unprivileged containers**:
  docker's first-mount copy-up leaves them root-owned while Mailu
  2024.06 drops to uid 100. Each Mailu-image service now fixes the
  ownership of its own volumes right before startup (a no-op on healthy
  deployments).

### Changed

- **All fourteen images pinned by `tag@sha256:digest`** in the compose
  `x-images` block: Mailu 2024.06.58 across the Mailu images, the
  antivirus image moved to `clamav/clamav-debian:1.4` and full-text
  attachments to `apache/tika` (matching upstream Mailu 2024.06 — the
  old `ghcr.io/mailu/clamav` and `fts-attachments` image names do not
  exist for this release), Redis 7.4, Traefik 3.7 (3.2's Docker client
  cannot talk to Docker Engine 29).
- `TLS_FLAVOR` is documented honestly: Traefik terminates TLS for the
  web hostnames only; the mail ports (465/993/995) are TCP passthrough
  and need certificates in the `mailu-certificates` volume (export from
  Traefik with a certs-dumper, or mount your own).

### Added

- **Deployment Verification workflow**: actionlint; Trivy scans of the
  eight most exposed pinned images; weekly `check-pin-freshness`; and a
  deploy-and-test job that boots all fourteen services and requires the
  admin UI and webmail through Traefik plus a live SMTP banner through
  the TCP router.

[Unreleased]: https://github.com/heyvaldemar/mailu-traefik-letsencrypt-docker-compose/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/heyvaldemar/mailu-traefik-letsencrypt-docker-compose/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/heyvaldemar/mailu-traefik-letsencrypt-docker-compose/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/heyvaldemar/mailu-traefik-letsencrypt-docker-compose/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/heyvaldemar/mailu-traefik-letsencrypt-docker-compose/releases/tag/v1.0.0
