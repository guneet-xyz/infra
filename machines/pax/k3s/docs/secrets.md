# Secrets

## Secrets

Sensitive values (API tokens, passwords) must use Kubernetes Secrets, not
ConfigMaps.

### Naming

Secret names should be descriptive of their purpose, not prefixed with the
app name. Since each chart deploys into its own namespace, there is no risk
of collision. Examples:

- `app-secret`, main app secrets
- `postgres-secret`, database credentials
- `cloudflare-secret`, Cloudflare API token

### Obscuro

Secrets are managed with [Obscuro](https://github.com/janklabs/obscuro).
Encrypted secrets are stored in `.obscuro/secrets.json` and are safe to
commit. Obscuro acts as a Helm post-renderer, replacing `__KEY__`
placeholders in rendered manifests with decrypted values.

#### Workflow

```sh
# First time setup, store password in OS keychain
obscuro auth store

# Store a secret
obscuro set SECRET_KEY

# List all secret names
obscuro list

# Deploy with post-renderer (password retrieved from keychain automatically)
kubolt install <chart>
```

Obscuro resolves the password in this order:
1. `--password` / `-p` flag
2. OS keychain (macOS Keychain / Linux Secret Service)
3. `OBSCURO_PASSWORD` environment variable
4. Interactive TTY prompt

#### Placeholder Convention

In Secret templates, use `__KEY__` placeholders for sensitive values:

```yaml
stringData:
  API_TOKEN: __API_TOKEN__
```

Non-sensitive config (database names, ports, hostnames) can use regular
Helm values.

#### Current Secrets

| Key | Used by |
|---|---|
| `CLOUDFLARE_API_TOKEN` | caddy |
| `WALLS_AUTH_SECRET` | walls |
| `WALLS_POSTGRES_PASSWORD` | walls (postgres) |
| `SMTP_USERNAME` | shared (walls, litellm, infisical) |
| `SMTP_PASSWORD` | shared (walls, litellm, infisical) |
| `GITHUB_API_KEY` | litellm |
| `GITHUB_MODELS_API_KEY` | litellm (GitHub Models embeddings) |
| `LITELLM_MASTER_KEY` | litellm |
| `LITELLM_POSTGRES_PASSWORD` | litellm (postgres) |
| `INFISICAL_AUTH_SECRET` | infisical |
| `INFISICAL_ENCRYPTION_KEY` | infisical |
| `INFISICAL_DB_CONNECTION_URI` | infisical |
| `INFISICAL_POSTGRES_PASSWORD` | infisical (postgres) |
| `REGISTRY_HTPASSWD` | registry |
| `REGISTRY_USERNAME` | registry-ui |
| `REGISTRY_PASSWORD` | registry-ui |
| `REGISTRY_PUBLIC_HTPASSWD` | caddy (Caddy basic_auth bcrypt hash for cr.guneet.dev pushes) |
| `REGISTRY_PUBLIC_PASSWORD` | none in cluster (Obscuro-stored plaintext for operator records / docker login docs) |
| `REGISTRY_PUBLIC_USERNAME` | caddy (Caddy basic_auth username for cr.guneet.dev pushes) |
| `REGISTRY_SESSION_SECRET` | registry-ui |
| `TS_CLIENT_ID` | tailscale |
| `TS_CLIENT_SECRET` | tailscale |
| `DEMO_SSH_AUTHORIZED_KEYS` | demo (SSH public keys, one per line) |
| `SYNAPSE_SIGNING_KEY` | synapse (federation signing key; IMMUTABLE — never regenerate) |
| `SYNAPSE_POSTGRES_PASSWORD` | synapse (postgres) |
| `SYNAPSE_REGISTRATION_SHARED_SECRET` | synapse (register_new_matrix_user) |
| `SYNAPSE_MACAROON_SECRET_KEY` | synapse (access token issuance) |
| `SYNAPSE_FORM_SECRET` | synapse (form CSRF) |
| `TURN_SHARED_SECRET` | coturn (shared secret for TURN ↔ Synapse authentication) |
| `EASYSHELL_POSTGRES_PASSWORD` | easyshell (postgres) |
| `EASYSHELL_NEXTAUTH_SECRET` | easyshell (website) |
| `EASYSHELL_DISCORD_CLIENT_ID` | easyshell (website) |
| `EASYSHELL_DISCORD_CLIENT_SECRET` | easyshell (website) |
| `EASYSHELL_GITHUB_CLIENT_ID` | easyshell (website) |
| `EASYSHELL_GITHUB_CLIENT_SECRET` | easyshell (website) |
| `EASYSHELL_GOOGLE_CLIENT_ID` | easyshell (website) |
| `EASYSHELL_GOOGLE_CLIENT_SECRET` | easyshell (website) |
| `EASYSHELL_COORDINATOR_TOKEN` | easyshell (website ↔ coordinator shared) |
| `EASYSHELL_COORDINATOR_REGISTRATION_TOKEN` | easyshell (coordinator ↔ thinkcentre runner shared) |
| `EASYSHELL_COORDINATOR_SECRET_KEY` | easyshell (coordinator AES-GCM for runner secret storage; IMMUTABLE — see chart README) |
| `EASYSHELL_RUNNER_ID` | thinkcentre easyshell-runner (bootstrap-generated) |
| `EASYSHELL_RUNNER_SECRET` | thinkcentre easyshell-runner (bootstrap-generated) |
| `EASYSHELL_POSTHOG_HOST` | easyshell (website) |
| `EASYSHELL_POSTHOG_KEY` | easyshell (website; NEXT_PUBLIC_POSTHOG_KEY at runtime) |
| `EASYSHELL_REGISTRY_DOCKERCONFIG_JSON` | easyshell (namespace-local imagePullSecret for cr.guneet.xyz; generate with `kubectl create secret docker-registry --dry-run=client -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d` — see chart README) |

## Shared SMTP Config

Non-sensitive SMTP configuration is in `values-shared.yaml` under `smtp`:

```yaml
smtp:
  host: <smtp-host>
  port: "587"
  mailFrom: <sender-email>
```

SMTP credentials (`SMTP_USERNAME`, `SMTP_PASSWORD`) are Obscuro secrets.
