# homepage

Dashboard for all services on pax, powered by
[Homepage](https://gethomepage.dev). Available at `home.guneet.xyz`
(private, Tailscale only).

> For install/upgrade/uninstall and backup commands, see [`../../docs/operations.md`](../../docs/operations.md) and [`../../docs/backup.md`](../../docs/backup.md).

## Configuration

All Homepage config is in `templates/configmap.yaml`. Edit the services,
bookmarks, widgets, and settings inline, then run `kubolt install homepage`.

See [Homepage docs](https://gethomepage.dev/configs/) for config reference.

## RBAC

This chart creates a ClusterRole and ClusterRoleBinding granting read-only
access to namespaces, pods, nodes, ingresses, and metrics. This is required
for the Kubernetes cluster stats widget.
