# honcho

[Honcho](https://honcho.dev) — stateful agent memory service. Provides a
workspace/peer/session/message hierarchy for storing and retrieving
conversational context for AI agents.

## Install

From the `machines/pax/k3s/` directory:

```sh
kubolt install honcho
```

## Upgrade

```sh
kubolt install honcho
```

## Uninstall

```sh
kubolt uninstall honcho
```

## Access

- Private: `https://honcho.guneet.xyz` (tailscale-only)

## Components

- `api` — FastAPI server on port 8000; runs DB migrations on startup
- `deriver` — background worker that processes messages asynchronously
- `postgres` — PostgreSQL with pgvector extension for vector similarity
- `redis` — ephemeral cache (emptyDir, data lost on restart)

## Verify

```sh
# All pods Running
kubectl get pods -n honcho

# pgvector extension installed
kubectl exec -n honcho deploy/honcho-postgres -- \
  psql -U honcho -d honcho -c \
  "SELECT extname FROM pg_extension WHERE extname = 'vector';"

# External health check (requires tailscale)
curl -sf https://honcho.guneet.xyz/health
```

## Backup

```sh
kubolt backup --dir ./backups honcho
```

## Notes

- Auth is disabled (`AUTH_USE_AUTH=false`). Access is controlled by
  tailscale network isolation and NetworkPolicies.
- LLM calls route through the existing litellm instance at
  `llm.guneet.xyz`. Honcho reasoning/dialectic/summary/dream workers are
  pinned to `gpt-5.4`, which is exposed by the cluster LiteLLM config.
- Automatic message embeddings are enabled (`EMBED_MESSAGES=true`) and route
  through LiteLLM. LiteLLM exposes `text-embedding-3-small` using the GitHub
  Models `openai/text-embedding-3-large` backend, with Honcho pinned to 1536
  embedding dimensions to match the existing pgvector schema.
- The deriver waits for the api to be healthy (initContainer) to avoid
  migration race conditions.
- Redis uses `emptyDir`, so cache data is lost on pod restart. That's
  acceptable for this workload.
- DB connection uses the `postgresql+psycopg://` prefix (SQLAlchemy
  psycopg3 driver requirement).

## Obscuro Secrets

| Key | Description |
|---|---|
| `HONCHO_POSTGRES_PASSWORD` | Postgres password for the honcho DB |
| `LITELLM_MASTER_KEY` | LiteLLM master key (shared, for LLM routing) |
