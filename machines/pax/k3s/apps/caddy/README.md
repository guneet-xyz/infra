# caddy

Unified reverse proxy chart with public and private instances.

- **caddy-public** — bound to `172.16.0.5` (eth0, public VNet), serves `*.guneet.dev`
- **caddy-private** — bound to `100.100.1.3` (tailscale0), serves `*.guneet.xyz`

Both instances share a single Cloudflare API token and a shared PVC for
TLS certificate cache.

## Install

From the `k3s/` directory:

```sh
./deploy.sh caddy install
```

## Upgrade

```sh
./deploy.sh caddy upgrade
```

## Uninstall

```sh
./deploy.sh caddy uninstall
```

## Routes

### Public (`*.guneet.dev`)

| Domain | Backend |
|---|---|
| `walls.guneet.dev` | walls |
| `llm.guneet.dev` | litellm |

### Private (`*.guneet.xyz`)

| Domain | Backend |
|---|---|
| `headlamp.guneet.xyz` | headlamp |
| `llm.guneet.xyz` | litellm |
| `chat.guneet.xyz` | openwebui |
| `db.guneet.xyz` | dev-db (HTTP→pgui, TCP/5432→postgres) |

## Migration from caddy-public

If upgrading from the old `caddy-public` chart:

```sh
helm uninstall caddy-public -n caddy-public
kubectl delete namespace caddy-public
./deploy.sh caddy install
```

## Obscuro Secrets

| Key | Description |
|---|---|
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token for DNS ACME |
