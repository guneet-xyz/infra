# infisical agent context

[Infisical](https://infisical.com) is the secrets management platform deployed
publicly at `infisical.guneet.dev`. This chart bundles the app with its own
Postgres and Redis, all wired together through Obscuro-managed secrets.

For general k3s/Helm conventions (chart structure, values layout, secrets,
networking, backups), see `machines/pax/k3s/AGENTS.md`.

## Read this when

- Changing the infisical chart, secret template, or `app-secret` env vars
- Touching the Postgres or Redis sidecar Deployments inside this chart
- Adjusting SMTP, domain, or any cross-component config
- Considering any kind of key rotation (encryption, auth, DB URI)

## Architecture

Three components must all be Running for infisical to function:

1. **infisical app** (`infisical-deployment.yaml`), the Node.js app exposing
   port `8080` and rendered via `app-secret` (`envFrom: secretRef`).
2. **Postgres**, a separate Deployment rendered from the shared
   `shared/postgres` library chart (`postgres-deployment.yaml`,
   `postgres-service.yaml`, `postgres-pvc.yaml`, `postgres-secret.yaml`).
   There is no Postgres sidecar inside the infisical pod; it is a fully
   separate workload.
3. **Redis**, a standalone Deployment in `redis-deployment.yaml`. Uses
   `emptyDir` for `/data`, so Redis state is ephemeral by design.

The three NetworkPolicies in `templates/networkpolicy.yaml` enforce:

- default deny ingress on the namespace
- caddy → infisical app on `port`
- infisical app → its Postgres on the Postgres port
- infisical app → its Redis on the Redis port

## Secrets

`templates/infisical-secret.yaml` is the `app-secret` Opaque Secret. It
combines static config (`SITE_URL`, `REDIS_URL`, shared SMTP host/port/from)
with Obscuro-injected sensitive values. The deployment loads everything via
`envFrom: secretRef: app-secret`.

Obscuro-injected keys:

| Placeholder | Purpose |
|---|---|
| `INFISICAL_ENCRYPTION_KEY` | AES-256 key used to encrypt stored secrets in the database. If this changes and the DB still contains data encrypted with the old key, ALL stored secrets become unreadable. Never rotate without a migration plan. |
| `INFISICAL_AUTH_SECRET` | JWT signing secret. Rotating it invalidates all active user sessions. |
| `INFISICAL_DB_CONNECTION_URI` | Full Postgres connection string. Overrides the per-env DB vars and currently points at the in-cluster Postgres rendered by this chart. |
| `INFISICAL_POSTGRES_PASSWORD` | Password used by the Postgres container itself; must stay in sync with the password embedded in `INFISICAL_DB_CONNECTION_URI`. |
| `SMTP_USERNAME` / `SMTP_PASSWORD` | Shared SMTP credentials (used by walls and litellm too). |

Non-sensitive SMTP config (`smtp.host`, `smtp.port`, `smtp.mailFrom`) comes
from `values-shared.yaml`. SMTP is used for magic-link auth emails and
organization invites; if SMTP is broken, new logins and invites silently
fail.

## Domain

- Public: `infisical.guneet.dev` (routed through caddy-public).
- `SITE_URL` in the Secret is derived from `apps.infisical.domain` in
  `values.yaml`. Changing the domain requires updating both this value and
  the caddy route.

## Backup

Postgres is the only stateful component that needs backing up. Redis is
ephemeral (emptyDir) and is not backed up.

```sh
kubolt backup --dir ./backups infisical
```

## Validate

```sh
kubolt validate
kubectl get pods -n infisical
curl -sf https://infisical.guneet.dev
```

All three Deployments (`infisical`, `infisical-postgres`, `infisical-redis`)
should be Running before the HTTP check passes.

## Footguns

- Rotating `INFISICAL_ENCRYPTION_KEY` without first migrating encrypted data
  with the old key in place = every stored secret becomes permanently
  unreadable. There is no recovery without the old key.
- Rotating `INFISICAL_AUTH_SECRET` = all active sessions are invalidated
  and users must re-authenticate. Usually fine, but coordinate if many
  active users.
- Pointing `INFISICAL_DB_CONNECTION_URI` at a different database (e.g.
  during a migration test) without first verifying it has an up-to-date
  schema = startup failures or, worse, partial writes against the wrong
  DB and data corruption.
- `INFISICAL_POSTGRES_PASSWORD` and the password embedded in
  `INFISICAL_DB_CONNECTION_URI` must match. They are two separate Obscuro
  keys; updating only one breaks login from the app to the DB.
- SMTP outage silently breaks magic-link login and org invites; the app
  itself stays "healthy". Watch SMTP_* values when triaging auth issues.

## Do not

- Do not change `INFISICAL_ENCRYPTION_KEY` unless you are following an
  explicit, tested key-rotation migration that re-encrypts existing data
  with the new key.
- Do not point `INFISICAL_DB_CONNECTION_URI` at a different database
  without first verifying it has an up-to-date schema and migration
  state matching the app version.
- Do not move sensitive values (encryption key, auth secret, DB URI,
  Postgres password, SMTP creds) into `values.yaml` or `values-shared.yaml`,
  they must stay as `__KEY__` placeholders resolved by Obscuro.
- Do not remove the Redis Deployment; the app expects `REDIS_URL` to
  resolve, even though the data itself is ephemeral.
