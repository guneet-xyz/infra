# plane

## What

Plane Community Edition, a project management tool. Wrapped via Helm
dependency on `plane-ce@1.5.1` from https://helm.plane.so/.

## Upstream chart

- Chart: `plane-ce 1.5.1`
- Repository: `https://helm.plane.so/`
- Vendored in `charts/`.

## URL

`https://plane.guneet.xyz`

> For install/upgrade/uninstall and backup commands, see [`../../docs/operations.md`](../../docs/operations.md) and [`../../docs/backup.md`](../../docs/backup.md).

## Prerequisites

- DNS: `plane.guneet.xyz` CNAME → `pax.ts.guneet.xyz`, resolving to the
  caddy-private Tailscale address. Access is Tailscale-only; the public
  caddy ingress is not used for this app.
- Secrets: `.obscuro/secrets.json` must contain exactly these 5 keys:
  - `PLANE_SECRET_KEY` → application secret key (generate with
    `openssl rand -hex 32`)
  - `PLANE_LIVE_SERVER_SECRET_KEY` → live (WebSocket) server secret
    (generate with `openssl rand -hex 32`)
  - `PLANE_POSTGRES_PASSWORD` → postgres database password
  - `PLANE_RABBITMQ_PASSWORD` → rabbitmq default user password
  - `PLANE_MINIO_ROOT_PASSWORD` → minio root password

## Backup

Handled by kubolt: `pg_dump` from the postgres pod plus a filesystem
snapshot of the minio PVC. No manual steps needed.

## First-time setup

Visit `https://plane.guneet.xyz` to create the first admin user. The
`/god-mode` path exposes the instance admin panel; consider restricting it
via Caddy auth or VPN for production use.
