# easyshell

Easyshell coding challenge platform — website + coordinator on pax k3s, runner on thinkcentre.

> For install/upgrade/uninstall and backup commands, see [`../../docs/operations.md`](../../docs/operations.md) and [`../../docs/backup.md`](../../docs/backup.md).

## Access

- Public: `https://easyshell.sh`
- Coordinator (tailnet): `https://coordinator.easyshell.sh`

## Obscuro Secrets

| Key | Description |
|---|---|
| `EASYSHELL_POSTGRES_PASSWORD` | Password for the in-cluster `easyshell-postgres` Postgres and embedded in the app `DATABASE_URL`. |
| `EASYSHELL_NEXTAUTH_SECRET` | NextAuth.js session/JWT signing secret for the website. Rotating invalidates all active user sessions. |
| `EASYSHELL_DISCORD_CLIENT_ID` | Discord OAuth application client ID. |
| `EASYSHELL_DISCORD_CLIENT_SECRET` | Discord OAuth application client secret. |
| `EASYSHELL_GITHUB_CLIENT_ID` | GitHub OAuth application client ID. |
| `EASYSHELL_GITHUB_CLIENT_SECRET` | GitHub OAuth application client secret. |
| `EASYSHELL_GOOGLE_CLIENT_ID` | Google OAuth application client ID. |
| `EASYSHELL_GOOGLE_CLIENT_SECRET` | Google OAuth application client secret. |
| `EASYSHELL_COORDINATOR_TOKEN` | Shared bearer token the website uses to authenticate to the coordinator API. Must match the coordinator's configured token. |
| `EASYSHELL_COORDINATOR_REGISTRATION_TOKEN` | Bootstrap token a runner presents once to register itself with the coordinator; must match the value in the thinkcentre runner `.env`. |
| `EASYSHELL_COORDINATOR_SECRET_KEY` | **IMMUTABLE.** AES key the coordinator uses to encrypt/decrypt persisted runner secrets. Rotating it invalidates every runner's stored secret. Never change without a full re-encryption plan. |
| `EASYSHELL_RUNNER_ID` | Bootstrap-generated. Assigned by the coordinator when a runner first registers; stored back in Obscuro so the runner can restart with a stable identity. |
| `EASYSHELL_RUNNER_SECRET` | Bootstrap-generated. Long-lived credential returned by the coordinator alongside the runner ID; the runner uses it for all subsequent authenticated calls. |
| `EASYSHELL_POSTHOG_HOST` | PostHog ingest host (e.g. `https://us.i.posthog.com`) for website product analytics. |
| `EASYSHELL_POSTHOG_KEY` | PostHog project API key for website product analytics. |
| `EASYSHELL_REGISTRY_DOCKERCONFIG_JSON` | Decoded `.dockerconfigjson` blob used to build the `easyshell-registry` imagePullSecret so pods can pull `cr.guneet.xyz/easyshell/*` images. |
| `SMTP_USERNAME` | SMTP auth username (shared across walls, infisical, easyshell). |
| `SMTP_PASSWORD` | SMTP auth password (shared across walls, infisical, easyshell). |

## Prerequisites

1. Cloudflare DNS A records: `easyshell.sh` → `172.16.0.5`, `coordinator.easyshell.sh` → `100.100.1.3`.
2. Cloudflare API token must have `Zone.DNS:Edit` permission on the `easyshell.sh` zone (the existing `CLOUDFLARE_API_TOKEN` is assumed to cover this).
3. Discord, GitHub, and Google OAuth apps registered with callbacks:
   - `https://easyshell.sh/api/auth/callback/discord`
   - `https://easyshell.sh/api/auth/callback/github`
   - `https://easyshell.sh/api/auth/callback/google`
4. Generate the coordinator secret key with:
   ```sh
   openssl rand -hex 32
   ```
5. Generate the registry `.dockerconfigjson` blob for Obscuro:
   ```sh
   kubectl create secret docker-registry tmp \
     --docker-server=cr.guneet.xyz \
     --docker-username=$REGISTRY_USERNAME \
     --docker-password=$REGISTRY_PASSWORD \
     -o jsonpath='{.data.\.dockerconfigjson}' --dry-run=client | base64 -d
   ```
6. **Migrator image must exist before the first deploy.** The migrator has no upstream release workflow, so `cr.guneet.xyz/easyshell/migrator:latest` has to be pushed manually:
   ```sh
   cd /path/to/easyshell
   docker build . -f apps/migrator/Dockerfile -t cr.guneet.xyz/easyshell/migrator:latest
   docker push cr.guneet.xyz/easyshell/migrator:latest
   ```
   Repeat after any change to `packages/db` or `apps/migrator`. Long-term: propose a `release-migrator.yml` workflow upstream so the image can ship the same way as website and coordinator.

## Setup

```sh
# Generate and store all secrets
obscuro set EASYSHELL_POSTGRES_PASSWORD
obscuro set EASYSHELL_NEXTAUTH_SECRET
obscuro set EASYSHELL_DISCORD_CLIENT_ID
obscuro set EASYSHELL_DISCORD_CLIENT_SECRET
obscuro set EASYSHELL_GITHUB_CLIENT_ID
obscuro set EASYSHELL_GITHUB_CLIENT_SECRET
obscuro set EASYSHELL_GOOGLE_CLIENT_ID
obscuro set EASYSHELL_GOOGLE_CLIENT_SECRET
obscuro set EASYSHELL_COORDINATOR_TOKEN
obscuro set EASYSHELL_COORDINATOR_REGISTRATION_TOKEN
obscuro set EASYSHELL_COORDINATOR_SECRET_KEY   # use: openssl rand -hex 32
obscuro set EASYSHELL_POSTHOG_HOST
obscuro set EASYSHELL_POSTHOG_KEY
obscuro set EASYSHELL_REGISTRY_DOCKERCONFIG_JSON   # see Prerequisites

# Shared SMTP secrets — skip if already set for walls/infisical
obscuro set SMTP_USERNAME
obscuro set SMTP_PASSWORD

# Deploy
kubolt install easyshell
```

## Upgrade

```sh
# Release workflows push new images to cr.guneet.xyz:
# - release-website.yml     → cr.guneet.xyz/easyshell/website:latest
# - release-coordinator.yml → cr.guneet.xyz/easyshell/coordinator:latest
# - (manual) rebuild migrator image per Prerequisites section
kubolt install easyshell   # Helm hook runs migrations, then rolls deployments
# Or force restart after a manual image push:
kubectl -n easyshell rollout restart deploy/easyshell deploy/easyshell-coordinator
```

## Backup

```sh
kubolt backup --dir ./backups easyshell
```

Scales the website and coordinator Deployments to 0, `pg_dump`s
`easyshell-postgres`, then restores the original replica counts.

## Migrations

The Helm `pre-install`/`pre-upgrade` Hook Job named `easyshell-migrate` pulls
`cr.guneet.xyz/easyshell/migrator:latest`, connects to Postgres via
`DATABASE_URL` from `coordinator-secret`, and runs
`pnpm exec drizzle-kit migrate` (the migrator image's ENTRYPOINT). If the Job
fails, the release rolls back automatically. Verify with:

```sh
kubectl -n easyshell get jobs
kubectl -n easyshell logs job/easyshell-migrate
```

## Do not

- **Do not rotate `EASYSHELL_COORDINATOR_SECRET_KEY`** without a plan to
  re-encrypt all stored runner secrets. It is IMMUTABLE for practical
  purposes — rotating it invalidates every runner's persisted secret and
  there is no recovery without the old key.
- **Do not rotate `EASYSHELL_COORDINATOR_REGISTRATION_TOKEN`** without also
  updating the thinkcentre runner `.env` (re-render with
  `obscuro inject --strict < .env.runtime.template > .env` and
  `docker compose up -d`). Otherwise the runner cannot re-register after a
  restart.
- **Do not advance `imageTag` from `latest`** without confirming the migrator
  image was also rebuilt against a compatible schema version. Website and
  coordinator will crash-loop if they start against a database whose schema
  is out of sync with the code.
