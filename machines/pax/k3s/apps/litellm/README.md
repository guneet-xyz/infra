# litellm

LiteLLM proxy — unified API gateway for LLM providers. Chat routes through
GitHub Copilot models; embeddings route through GitHub Models. Backed by its
own PostgreSQL database.

> For install/upgrade/uninstall and backup commands, see [`../../docs/operations.md`](../../docs/operations.md) and [`../../docs/backup.md`](../../docs/backup.md).

## Access

- Private only: `https://llm.guneet.xyz` (Tailscale)

## Models

Chat models route through `github_copilot/`:

- `claude-opus-4.5`
- `claude-opus-4.6`
- `claude-opus-4.6-1m`
- `gpt-5.4`

Embedding models route through GitHub Models (`github/`):

- `text-embedding-3-large`
- `text-embedding-3-small` (alias to GitHub Models `openai/text-embedding-3-large`)

## Settings

- `drop_params: true` — silently drops unsupported params instead of
  erroring
- `callbacks: ["smtp_email"]` — email notifications via SMTP

## Obscuro Secrets

| Key | Description |
|---|---|
| `GITHUB_API_KEY` | GitHub Copilot API key |
| `GITHUB_MODELS_API_KEY` | GitHub Models PAT for embedding routes |
| `LITELLM_MASTER_KEY` | LiteLLM admin master key |
| `SMTP_USERNAME` | SMTP auth username (shared) |
| `SMTP_PASSWORD` | SMTP auth password (shared) |
