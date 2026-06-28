# honcho agent context

[Honcho](https://honcho.dev) is the stateful agent memory service deployed
privately at `honcho.guneet.xyz`. It stores workspace/peer/session/message
data with vector similarity search via pgvector and routes all LLM and
embedding calls through the cluster LiteLLM instance.

For general k3s/Helm conventions (chart structure, values layout, secrets,
networking, backups), see `machines/pax/k3s/AGENTS.md`.

## Read this when

- Changing the honcho chart, deriver, or LiteLLM routing config
- Touching the pgvector Postgres image, init scripts, or schema
- Updating the embedding model or its dimension
- Adjusting auth, NetworkPolicies, or the deriver startup order

## Architecture

Four components:

1. **honcho api** (`honcho-deployment.yaml`), FastAPI server on port `8000`.
   Runs `alembic` DB migrations on startup via the upstream
   `/app/docker/entrypoint.sh`. This is the only writer of schema
   migrations.
2. **honcho deriver** (`honcho-deriver-deployment.yaml`), background async
   worker that processes messages. Started with
   `/app/.venv/bin/python -m src.deriver`.
3. **honcho-postgres**, pgvector-enabled Postgres rendered from the shared
   `shared/postgres` library chart. Image is `pgvector/pgvector:pg16`,
   NOT a stock `postgres` image.
4. **honcho-redis** (`redis-deployment.yaml`), Redis for ephemeral cache
   only. Uses `emptyDir`, so its data is lost on pod restart. This is
   intentional, cache contents are not load-bearing.

NetworkPolicies in `templates/networkpolicy.yaml`: default-deny ingress,
caddy → api, deriver → api (for the initContainer health check and
runtime), api+deriver → postgres, api+deriver → redis.

## Startup order

The deriver Deployment has an `initContainer` named `wait-for-api` that
polls `http://<api>.<ns>.svc.cluster.local:<port>/health` until it returns
2xx before the deriver container starts. This is required because:

- The api runs `alembic upgrade head` at startup.
- The deriver queries tables the migrations create.
- Without the gate, the deriver crash-loops on a fresh DB until migrations
  finish, and on upgrades it can race a schema change.

If you remove or modify the initContainer, you reintroduce this race.

## pgvector

The Postgres image is `pgvector/pgvector:pg16` (see `values.yaml`). It is
a standard Postgres 16 image with the pgvector extension pre-installed.
The init script in `templates/postgres-init-configmap.yaml` runs once on
first DB init:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

The shared postgres library mounts the ConfigMap named by
`apps.honcho.postgres.initScripts` into `/docker-entrypoint-initdb.d/`,
so this only runs on a fresh data directory. **Do not replace this image
with a standard `postgres` image**, the `vector` extension would fail to
load and the schema migrations that create vector columns would fail.

## Driver requirement

Honcho's DB connection string uses the prefix `postgresql+psycopg://`,
which is the SQLAlchemy psycopg3 async driver. **It is not
`postgresql://` and not `postgresql+psycopg2://`.** If you regenerate or
hand-edit a connection string for honcho (in Obscuro or anywhere else),
this prefix must match exactly, otherwise SQLAlchemy fails to import the
driver at startup and the api crash-loops.

## LiteLLM coupling

Honcho does not call OpenAI directly. All LLM and embedding requests go
to the cluster LiteLLM instance at `llm.guneet.xyz`. This means LiteLLM
must be reachable and authorized via `LITELLM_MASTER_KEY` (shared with
litellm).

Model pinning (from the README):

- LLM workers (reasoning / dialectic / summary / dream): `gpt-5.4`
- Embeddings: `text-embedding-3-small`, 1536 dimensions, backed by the
  GitHub Models `openai/text-embedding-3-large` route exposed by LiteLLM.

If the embedding model or dimension changes, the pgvector column
dimension in the schema must also change. This is a destructive migration
because existing vectors stored at the old dimension cannot be reused at
a new dimension.

## Embedding dimensions

The pinned dimension is **1536**. It must match:

- LiteLLM's exposed `text-embedding-3-small` output dimension.
- The pgvector column definition in the honcho schema.

If any of those three disagree, ingest writes fail or the api refuses to
start.

## Auth

Auth is disabled: `AUTH_USE_AUTH=false`. Access is controlled entirely by:

- Tailscale (the private endpoint `honcho.guneet.xyz` is only reachable
  from the tailscale network), and
- the NetworkPolicies in this chart.

If you want to enable auth, you also need to update every honcho client
SDK to send the right credentials. Do not flip the flag without
coordinating with all consumers.

## Backup

```sh
kubolt backup --dir ./backups honcho
```

This `pg_dump`s the postgres data PVC. The Redis emptyDir is intentionally
not backed up.

## Validate

```sh
kubectl get pods -n honcho

# pgvector extension installed in the DB
kubectl exec -n honcho deploy/honcho-postgres -- \
  psql -U honcho -d honcho -c \
  "SELECT extname FROM pg_extension WHERE extname = 'vector';"

# Health endpoint reachable over tailscale
curl -sf https://honcho.guneet.xyz/health
```

All four workloads (`honcho`, `honcho-deriver`, `honcho-postgres`,
`honcho-redis`) should be Running before the HTTP check passes.

## Footguns

- Changing the pgvector embedding dimension without migrating the vector
  column = startup failure on next embed, or silent dimension mismatch
  errors from the DB.
- Using a non-pgvector Postgres image (e.g. plain `postgres:16`) = the
  `vector` extension is unavailable, `CREATE EXTENSION` fails, schema
  migrations fail, api crash-loops.
- Changing the `postgresql+psycopg://` prefix to `postgresql://` or
  `postgresql+psycopg2://` = driver mismatch crash at startup.
- Removing the deriver's `wait-for-api` initContainer = migration race
  on fresh installs and upgrades.
- LiteLLM outage or bad `LITELLM_MASTER_KEY` = honcho stops embedding and
  reasoning; api may still answer reads but writes that derive memory
  silently degrade.

## Do not

- Do not replace `pgvector/pgvector:pg16` with a standard `postgres` image.
- Do not change the embedding dimension (currently 1536) without also
  migrating the pgvector column and re-embedding existing rows.
- Do not change the driver prefix in any honcho DB connection string;
  it must stay `postgresql+psycopg://`.
- Do not enable `AUTH_USE_AUTH` without first updating every honcho
  client SDK; honcho will start refusing unauthenticated requests.
- Do not remove the deriver `initContainer` that waits for the api
  health endpoint.
