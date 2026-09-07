# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_(no unreleased changes yet)_

## [1.7.2] - 2026-09-07

### Changed

- **`update.sh` names any new required variable before it moves.** An update can add a required variable; `docker compose up` used to stop on it after the checkout, with the tree already on the new tag. The script now lists the variables that appeared in `.env.example` since your version and refuses, before anything has moved, when a required one is not in your `.env`. Names only, never values.

hem
  follows `apache/tika:latest-full`, a tag that moves by design, frozen at a
  digest nobody was watching. All six are current as of today, which is luck
  rather than a result.

### Changed

- **The job enumerates the pins out of the compose file instead of naming
  them.** A pin that exists is a pin that is watched, and a list cannot fall
  behind the file it describes. An image built from source is skipped rather
  than looked up under a name no registry serves.

## [1.7.0] - 2026-09-04

### Fixed

- **A backup interrupted halfway no longer looks like a good one.** The loop
  already renamed a failed dump to `.failed` so nothing would restore from it,
  but that rename only runs if the shell lives long enough to reach it. Stop
  the container mid-dump and it does not: the truncated file keeps the name a
  finished backup would have, and it is the newest one, which is exactly what
  the restore script and the end-to-end test pick. Every backup is now written
  to `<name>.partial` and renamed only after the dump succeeds, so the real
  name never exists unless the file behind it is complete. Verified by killing
  a dump in flight: before, the restore path selected a file that failed
  `gzip -t`; after, it finds nothing to select.

## [1.6.0] - 2026-09-04

### Added

- **A shutdown grace period for Redis.** Docker stops a container with
  SIGTERM and ten seconds, then SIGKILL. That default is not always enough:
  PostgreSQL has a checkpoint to write, MariaDB has InnoDB to flush, and Redis
  saves its dataset on the way out. Killed halfway, the next start does crash
  recovery, and a Redis holding another application's file locks leaves them
  behind for a person to clear by hand. Sixty seconds now, overridable per
  service with `<PREFIX>_STOP_GRACE_PERIOD` in `.env`. The backup sidecar is
  deliberately left alone: its failure mode is a truncated dump file, which a
  longer grace period does not fix.

## [1.5.0] - 2026-09-03

### Added

- **Per-image version overrides.** Every pin in the `x-images` block is
  now `${<PREFIX>_IMAGE_TAG:-repo:${<PREFIX>_IMAGE_VERSION:-tag@sha256:digest}}`.
  Set `<PREFIX>_IMAGE_VERSION` in `.env` to run a different version of one
  image while every other pin stays as tested (Compose pulls that tag
  without a digest), or `<PREFIX>_IMAGE_TAG` to replace the whole
  reference as before. A deployment that sets neither is unchanged. The
  freshness job, the Trivy matrix and the fleet digest automation resolve
  the nested default before reading a pin. Needs Docker Compose v2.5 or
  newer (2022): v2.0 to v2.4 leave the inner `${...}` unexpanded and
  `docker compose up` fails with an invalid reference instead of
  deploying something unexpected.

## [1.4.0] - 2026-09-02

### Security

- **Container hardening.** Every service runs with
  `security_opt: no-new-privileges:true` (no privilege escalation via
  setuid binaries even if a process escapes its initial capability
  set). Infrastructure containers (the reverse proxy, databases,
  caches, backups) drop every Linux capability and add back only what
  their entrypoints need (bind :80/:443, chown a data directory, drop to
  the service user). Application containers keep the default capability
  set: upstream images assume it, and a wrong guess there is a boot loop
  in production, not a hardening win. CI boots the stack under these
  settings on every push.

### Added

- **`tests/e2e-backup-restore.sh`**: scenarios against the live stack,
  run by CI on every push: the required-variable guard fires, a backup
  set is produced, the archive is readable, the database copy passes `PRAGMA integrity_check`, a cycle that cannot
 write its archive is reported as `FAILED`, **restore 
  replaces the data** (the application is stopped, the baseline database copy is put back, and a row inserted after the baseline is gone), and pruning removes only old files.

## [1.3.1] - 2026-09-02

### Fixed

- A database file that does not exist yet (the application creates it on
  first start) is skipped with a note instead of being reported as a
  failed backup; the first cycle after a fresh install no longer logs
  `FAILED`.

## [1.3.0] - 2026-09-02

### Added

- **A `backups` service** for the admin database (users, domains, aliases), the DKIM keys and every mailbox: on a loop it takes a consistent copy of each SQLite database (`main.db`) through Python's `sqlite3` backup API - no application stop - and a `tar.gz` of the rest of the data directory (live database files excluded), logs `OK` or `FAILED` per artefact (a failed archive is kept as `.failed`), and prunes only its own files. Schedule knobs (`MAILU_BACKUP_INIT_SLEEP`, `MAILU_BACKUP_INTERVAL`, `MAILU_BACKUP_PRUNE_DAYS`, path and names) have defaults listed in `.env.example`.
- **`mailu-restore-data.sh`**: interactive restore of a backup set: stops mailu, unpacks the data archive, restores each database copy, starts mailu.
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

- **`update.sh`**: unattended updates to the newest tagged release,
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
  every service loads via `env_file:`. A fresh clone could not start at
  all, and the README documented almost none of it. `.env.example` now
  carries the full contract: Traefik settings, the three routed
  hostnames, and the Mailu application config (SECRET_KEY, DOMAIN,
  HOSTNAMES, TLS_FLAVOR, the initial admin account, and the commonly
  tuned options).
- The tracked `.env` also carried a real `SECRET_KEY`. Rotate it if
  your deployment reused it (rotating invalidates sessions and signed
  tokens, not mailboxes).

### Fixed (found by the new CI)

- **fetchmail shared the admin database volume.** fetchmail runs as its
  own user (uid 101) and chowns its data directory at startup, on a
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
  attachments to `apache/tika` (matching upstream Mailu 2024.06, the
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

[Unreleased]: https://github.com/heyvaldemar/mailu-traefik-letsencrypt-docker-compose/compare/v1.7.2...HEAD
[1.7.2]: https://github.com/heyvaldemar/mailu-traefik-letsencrypt-docker-compose/compare/v1.7.1...v1.7.2
[1.7.1]: https://github.com/heyvaldemar/mailu-traefik-letsencrypt-docker-compose/compare/v1.7.0...v1.7.1
[1.7.0]: https://github.com/heyvaldemar/mailu-traefik-letsencrypt-docker-compose/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/heyvaldemar/mailu-traefik-letsencrypt-docker-compose/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/heyvaldemar/mailu-traefik-letsencrypt-docker-compose/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/heyvaldemar/mailu-traefik-letsencrypt-docker-compose/compare/v1.3.1...v1.4.0
[1.3.1]: https://github.com/heyvaldemar/mailu-traefik-letsencrypt-docker-compose/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/heyvaldemar/mailu-traefik-letsencrypt-docker-compose/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/heyvaldemar/mailu-traefik-letsencrypt-docker-compose/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/heyvaldemar/mailu-traefik-letsencrypt-docker-compose/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/heyvaldemar/mailu-traefik-letsencrypt-docker-compose/releases/tag/v1.0.0
