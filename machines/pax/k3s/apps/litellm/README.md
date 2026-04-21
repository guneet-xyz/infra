# litellm

LiteLLM proxy — unified API gateway for LLM providers. Routes through
GitHub Copilot models. Backed by its own PostgreSQL database.

## Install

From the `k3s/` directory:

```sh
./deploy.sh litellm install
```

## Upgrade

```sh
./deploy.sh litellm upgrade
```

## Uninstall

```sh
./deploy.sh litellm uninstall
```

## Access

- Public: `https://llm.guneet.dev`
- Private: `https://llm.guneet.xyz`

## Obscuro Secrets

| Key | Description |
|---|---|
| `GITHUB_API_KEY` | GitHub Copilot API key |
| `LITELLM_MASTER_KEY` | LiteLLM admin master key |
| `SMTP_USERNAME` | SMTP auth username (shared) |
| `SMTP_PASSWORD` | SMTP auth password (shared) |
