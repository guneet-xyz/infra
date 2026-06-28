# ntfy

ntfy — pub-sub notification service. Tailscale-only.

Upstream: https://ntfy.sh

> For install/upgrade/uninstall and backup commands, see [`../../docs/operations.md`](../../docs/operations.md) and [`../../docs/backup.md`](../../docs/backup.md).

## Access

- Private: `https://ntfy.guneet.xyz`

## Notes

- Auth disabled (open mode); access gated by Tailscale ACLs and Calico NetworkPolicy.
- Single-replica only (SQLite); upgrades use `Recreate` strategy and incur a brief 502 window.
- PVC deletion on `kubolt uninstall` deletes message cache irreversibly. Always `kubolt backup ntfy` before uninstalling.
- If pod fails to start as non-root UID 65532, fall back to running as root by removing `runAsUser`/`runAsGroup`/`runAsNonRoot` from the container `securityContext` in `templates/deployment.yaml` and document the deviation here.
