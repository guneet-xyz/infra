# homepage

Dashboard for all services on pax, powered by
[Homepage](https://gethomepage.dev). Available at `home.guneet.xyz`
(private, Tailscale only).

## Install

From the `machines/pax/k3s/` directory:

```sh
kubolt install homepage
```

## Upgrade

```sh
kubolt install homepage
```

## Uninstall

```sh
kubolt uninstall homepage
```

## Configuration

All Homepage config is in `templates/configmap.yaml`. Edit the services,
bookmarks, widgets, and settings inline, then run `kubolt install homepage`.

See [Homepage docs](https://gethomepage.dev/configs/) for config reference.

## RBAC

This chart creates a ClusterRole and ClusterRoleBinding granting read-only
access to namespaces, pods, nodes, ingresses, and metrics. This is required
for the Kubernetes cluster stats widget.
