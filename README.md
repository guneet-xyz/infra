# infra

Infrastructure repo organized by Kubernetes cluster.

## Layout

```
clusters/
  pax/                  # k3s single-node cluster
    apps/               # Helm charts (13 apps)
    shared/             # Helm library charts
    plugins/            # Helm post-renderers (obscuro for secrets)
    values-shared.yaml
    kubolt.yaml          # kubolt app/dependency/backup manifest
    AGENTS.md           # cluster-specific docs
```

Secrets config (`.obscuro/`) lives at the repo root so it's shared across clusters.

## Adding a new cluster

Add a sibling `clusters/<name>/` directory mirroring the `pax/` structure.

## Operating `pax`

See [`clusters/pax/AGENTS.md`](clusters/pax/AGENTS.md) for deploy, backup, and operate instructions.

## Tooling

k3s + Helm + [obscuro](https://github.com/janklabs/obscuro) for secrets.

- [kubolt](https://github.com/guneet-xyz/kubolt), Go CLI that wraps Helm for day-to-day cluster management (install, uninstall, validate, list, backup). Install with `curl -sSL https://raw.githubusercontent.com/guneet-xyz/kubolt/main/install.sh | sh`.

## Helm plugin caveat

If you previously installed the obscuro helm plugin from the old path, run `helm plugin remove obscuro` once before your next kubolt operation so Helm can use the current plugin path.
