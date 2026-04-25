# Registry

Self-hosted Docker Distribution (registry:3) with [CRUI](https://github.com/kvqn/crui) web frontend.

## Domain

- `cr.guneet.xyz` — private (Tailscale), `/v2/*` routes to registry API, everything else to CRUI

## Obscuro Secrets

Before installing, store these secrets with `obscuro set`:

| Key | Description |
|---|---|
| `REGISTRY_HTPASSWD` | htpasswd file content (generate with `htpasswd -Bn <user>`) |
| `REGISTRY_USERNAME` | Username for CRUI to authenticate with registry API |
| `REGISTRY_PASSWORD` | Password for CRUI to authenticate with registry API |
| `REGISTRY_SESSION_SECRET` | Random string for CRUI session signing |

## Install

```sh
./deploy.sh registry install
```

## Backup

Add `registry` to `backup.sh` (`ALL_APPS` and `pvcs_for_app`) to enable
PVC backups for `registry-data`.
