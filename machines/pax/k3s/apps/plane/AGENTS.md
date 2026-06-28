# plane agent context

For general k3s/Helm conventions (chart structure, values layout, secrets,
networking, backups), see `machines/pax/k3s/AGENTS.md`.

## Read this when

Editing anything under `apps/plane/`: `Chart.yaml`, `values.yaml`,
`templates/extra-secret.yaml`, the vendored `charts/` directory, or
Plane's entry in `values-shared.yaml`. Plane is an upstream umbrella
chart, not a hand-written chart, and the workflow differs from every
other app in this stack.

## Upstream chart wrapper

This chart wraps **`plane-ce` version `1.5.1`** pulled from
`https://helm.plane.so/` and **vendored** into `charts/` via
`helm dependency update`. `Chart.yaml` here declares one dependency
(`plane-ce`) and contains no templates of its own beyond
`extra-secret.yaml`.

Because Plane's own templates manage Deployments, Services, ConfigMaps,
Secrets, PVCs, and the in-cluster Postgres/Redis/RabbitMQ/MinIO stack,
this repo only adds:

- `templates/networkpolicy.yaml` — default-deny plus allow-from-caddy
- `templates/extra-secret.yaml` — **intentionally empty** (see below)

All Plane configuration lives under the `plane-ce:` key in
`values.yaml`. Helm passes those values straight through to the
upstream chart's templates.

## Six named services

Plane exposes six named services that the upstream chart creates from
its own templates. They are referenced from `caddy-private`'s Caddyfile
and indexed under `apps.plane.services.*` in `values-shared.yaml`:

| Service | Service name | Port | Routed Caddy path on `plane.guneet.xyz` |
|---|---|---|---|
| `web` | `plane-web` | 3000 | default (catch-all) |
| `space` | `plane-space` | 3000 | `/spaces`, `/spaces/*` |
| `admin` | `plane-admin` | 3000 | `/god-mode`, `/god-mode/*` |
| `api` | `plane-api` | 8000 | `/api/*`, `/auth/*` |
| `live` | `plane-live` | 3000 | `/live`, `/live/*` |
| `minio` | `plane-minio` | 9000 | `/uploads`, `/uploads/*` |

Caddy routes by path prefix to the appropriate service, so all six
service entries must stay aligned between `values-shared.yaml` and the
private Caddyfile. If you bump the upstream chart and a service name
changes, both sides need updating.

## Five Obscuro secrets

All required before the first install. The upstream chart bakes these
into its own Secret resources via `__PLACEHOLDER__` substitution at
deploy time (Obscuro post-renderer):

| Key | Where it lands |
|---|---|
| `PLANE_SECRET_KEY` | Plane app secret key |
| `PLANE_LIVE_SERVER_SECRET_KEY` | live (WebSocket) server secret |
| `PLANE_POSTGRES_PASSWORD` | in-cluster Postgres password |
| `PLANE_RABBITMQ_PASSWORD` | in-cluster RabbitMQ default-user password |
| `PLANE_MINIO_ROOT_PASSWORD` | in-cluster MinIO root password |

Generate the two application-level keys with `openssl rand -hex 32`.

## `extra-secret.yaml` is intentionally empty

`templates/extra-secret.yaml` contains **only comments**, no resources.
The upstream chart's `templates/config-secrets/` already creates every
Secret Plane needs (app-env, pgdb, rabbitmqdb, docker-registry,
doc-store, live-env). Adding anything here will collide or duplicate
upstream secrets. Leave it as a documentation-only placeholder.

## Upgrade flow

```sh
# 1. Bump dependency version in Chart.yaml
$EDITOR apps/plane/Chart.yaml          # change plane-ce version

# 2. Pull the new chart into charts/ and refresh Chart.lock
helm dependency update apps/plane

# 3. Commit the new charts/*.tgz and Chart.lock so the build is reproducible
git add apps/plane/charts apps/plane/Chart.lock
git commit -m "plane: bump plane-ce to <new-version>"

# 4. Install/upgrade via kubolt (NOT helm directly)
kubolt install plane
```

The README still says `kubolt apply plane`; that command does not
exist. The correct command is `kubolt install plane` (which kubolt uses
for both first install and upgrade, identical to every other chart in
this stack).

## Access

Plane is **Tailscale-only**. The domain `plane.guneet.xyz` resolves to
the caddy-private Tailscale address (`100.100.1.3`) and is **not**
exposed through caddy-public. Do not add any `plane.guneet.dev` route
or otherwise publish it on the public VNet.

## First-time setup

After the first successful install, visit
`https://plane.guneet.xyz/god-mode` to initialize the instance and
create the first admin user. The README also mentions visiting the root
domain; the `/god-mode` path is what bootstraps the instance.

`/god-mode` is the instance admin panel. In production it should be
behind extra protection (Caddy basic_auth on `@godmode` in the private
Caddyfile, or rely on Tailscale-only access).

## Validate

From `machines/pax/k3s/`:

```sh
kubolt validate
kubectl get pods -n plane
```

`kubolt validate` renders the upstream chart's templates with the
overrides in `values.yaml`. If you bump `plane-ce` and the render fails,
the upstream chart changed shape.

## Do not

- **Do not edit files inside `charts/`.** They are vendored upstream
  tarballs managed by `helm dependency update`. Any local change will
  be overwritten on the next dependency refresh.
- **Do not run `helm install` or `helm upgrade` manually.** Use
  `kubolt install plane` so `values-shared.yaml` merging, namespace
  creation, and the Obscuro post-renderer all run correctly.
- **Do not add resources to `templates/extra-secret.yaml`.** The
  upstream chart owns every Secret Plane needs. This file is a
  documentation stub on purpose.
- **Do not expose Plane through caddy-public.** It is Tailscale-only by
  design. No `*.guneet.dev` route.
- **Do not skip committing `charts/*.tgz` and `Chart.lock`** after a
  dependency update. The build is not reproducible without them.
