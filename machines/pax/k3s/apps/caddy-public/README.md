# caddy-public

Public-facing Caddy reverse proxy with Cloudflare DNS ACME integration.

## Install

From the `k3s/` directory:

```sh
helm install caddy-public ./apps/caddy-public \
  -n caddy-public --create-namespace \
  -f values-shared.yaml \
  -f apps/caddy-public/values.yaml \
  --post-renderer obscuro --post-renderer-args inject
```

## Upgrade

```sh
helm upgrade caddy-public ./apps/caddy-public \
  -n caddy-public \
  -f values-shared.yaml \
  -f apps/caddy-public/values.yaml \
  --post-renderer obscuro --post-renderer-args inject
```

## Uninstall

```sh
helm uninstall caddy-public -n caddy-public
```

## Obscuro Secrets

| Key | Description |
|---|---|
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token for DNS ACME |
