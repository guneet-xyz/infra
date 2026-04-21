# walls

Wallpaper sharing platform. Deploys the walls app with its own PostgreSQL database.

## Install

From the `k3s/` directory:

```sh
helm install walls ./apps/walls \
  -n walls --create-namespace \
  -f values-shared.yaml \
  -f apps/walls/values.yaml \
  --post-renderer obscuro --post-renderer-args inject
```

## Upgrade

```sh
helm upgrade walls ./apps/walls \
  -n walls \
  -f values-shared.yaml \
  -f apps/walls/values.yaml \
  --post-renderer obscuro --post-renderer-args inject
```

## Uninstall

```sh
helm uninstall walls -n walls
```

## Obscuro Secrets

| Key | Description |
|---|---|
| `WALLS_AUTH_SECRET` | Auth secret for magic link authentication |
| `SMTP_USERNAME` | SMTP auth username (shared) |
| `SMTP_PASSWORD` | SMTP auth password (shared) |
