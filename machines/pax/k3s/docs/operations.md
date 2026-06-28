# Operations

## Using kubolt

`kubolt` is the Go CLI for day-to-day cluster management. It wraps Helm with
the repo's secrets, dependency, backup, and validation logic as proper
subcommands.

Install:

```
curl -sSL https://raw.githubusercontent.com/guneet-xyz/kubolt/main/install.sh | sh
```

Common commands (run from this directory):

- `kubolt validate`, template all charts
- `kubolt list`, show install status for every chart
- `kubolt install [app]`, install or upgrade an app (and its dependencies), or every app in the manifest when no arg is given
- `kubolt uninstall <app>`, uninstall an app (blocks if dependents are still installed)
- `kubolt backup --dir ./backups <app>`, back up an app's PVCs

## Prerequisites

- `helm` installed
- `kubectl` configured with cluster access
- [`obscuro`](https://github.com/janklabs/obscuro) installed
- `obscuro init` run in the repo (`.obscuro/` is at the repo root)
- `obscuro auth store` to save the master password in the OS keychain
- Node labeled: `kubectl label node pax role=primary`
- **Calico** CNI installed (K3s must be started with
  `--flannel-backend=none --disable-network-policy`). Required for
  NetworkPolicy enforcement.

## Bootstrap Order

Services must be installed in this order due to dependencies:

1. **caddy**, routes public and private traffic, no app dependencies
2. **registry**, hosts container images for custom apps
3. **apps** (walls, headlamp, litellm, openwebui, etc.), depend on
   registry for images and caddy for routing

## Validation

Run `kubolt validate` from this directory to validate all charts. It renders
templates with Helm. Run this after any template or values changes.

## Installing a Chart

Use `kubolt` to install, upgrade, or uninstall charts. It reads app metadata
from `kubolt.yaml`, installs dependencies first, and passes the correct flags
to Helm.

```sh
kubolt install <chart>
kubolt uninstall <chart>
```

Kubolt handles `-n <namespace> --create-namespace`, merging
`values-shared.yaml`, and the Obscuro post-renderer.

See each chart's `README.md` for additional details.
