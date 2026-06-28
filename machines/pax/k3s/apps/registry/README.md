# Registry

Self-hosted Docker Distribution (registry:3) with [CRUI](https://github.com/kvqn/crui) web frontend.

## Domain

- `cr.guneet.xyz` — private (Tailscale), `/v2/*` routes to registry API, everything else to CRUI

> For install/upgrade/uninstall and backup commands, see [`../../docs/operations.md`](../../docs/operations.md) and [`../../docs/backup.md`](../../docs/backup.md).

## Obscuro Secrets

Store these secrets with `obscuro set`:

| Key | Description |
|---|---|
| `REGISTRY_HTPASSWD` | htpasswd file content (generate with `htpasswd -Bn <user>`) |
| `REGISTRY_USERNAME` | Username for CRUI to authenticate with registry API |
| `REGISTRY_PASSWORD` | Password for CRUI to authenticate with registry API |
| `REGISTRY_SESSION_SECRET` | Random string for CRUI session signing |

## Backup

`registry` has a backup target in `kubolt.yaml` for PVC backups of
`registry-data`:

```sh
kubolt backup --dir ./backups registry
```
