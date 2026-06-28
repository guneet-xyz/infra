# dev-db

Development PostgreSQL database + pgui web UI. Used as a scratch database for experimentation and ad-hoc queries.

## Install

From the `machines/pax/k3s/` directory:

```sh
kubolt install dev-db
```

## Upgrade

```sh
kubolt install dev-db
```

## Uninstall

```sh
kubolt uninstall dev-db
```

## Access

Both components are exposed via caddy-private at `db.guneet.xyz`:

- `https://db.guneet.xyz` — pgui web UI (HTTP via reverse_proxy)
- `db.guneet.xyz:5432` — raw Postgres TCP (via caddy-l4 layer4 proxy)

Only reachable from the tailnet (`*.guneet.xyz` convention).

## Components

| Resource | Image | Notes |
|---|---|---|
| Postgres | `postgres:17.9-alpine` | Single superuser `devdb`, db `devdb`, 5Gi PVC |
| pgui | `kvqn/pgui:latest` | https://github.com/janklabs/pgui, port 3000 |

## Obscuro Secrets

| Key | Description |
|---|---|
| `DEVDB_POSTGRES_PASSWORD` | Superuser password (shared by Postgres + pgui) |

To rotate:

```sh
obscuro set DEVDB_POSTGRES_PASSWORD
kubolt install dev-db
```

The `checksum/secret` annotation on the pgui Deployment ensures the pod restarts on password rotation.

## Backups

PVC `dev-db-postgres-data` is included in `kubolt.yaml`:

```sh
kubolt backup --dir ./backups dev-db
```

See the top-level `AGENTS.md` for the full backup workflow.
