# homepage

Dashboard for all services on pax, powered by
[Homepage](https://gethomepage.dev). Available at `home.guneet.xyz`
(private, Tailscale only).

## Install

From the `clusters/pax/` directory:

```sh
./deploy.sh homepage install
```

## Upgrade

```sh
./deploy.sh homepage upgrade
```

## Uninstall

```sh
./deploy.sh homepage uninstall
```

## Configuration

All Homepage config is in `templates/configmap.yaml`. Edit the services,
bookmarks, widgets, and settings inline, then run `./deploy.sh homepage upgrade`.

See [Homepage docs](https://gethomepage.dev/configs/) for config reference.

## RBAC

This chart creates a ClusterRole and ClusterRoleBinding granting read-only
access to namespaces, pods, nodes, ingresses, and metrics. This is required
for the Kubernetes cluster stats widget.
