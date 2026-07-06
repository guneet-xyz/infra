# infra

Infrastructure repo organized by machine. Each machine can own one or more
infra stacks, such as k3s, Docker Compose, host services, or provisioning
assets.

## Layout

```
machines/
  pax/                  # machine-specific infra for host `pax`
    AGENTS.md           # machine-level context
    README.md           # machine overview
    k3s/                # k3s stack running on pax
      apps/             # Helm charts
      shared/           # Helm library charts
      plugins/          # Helm post-renderers (obscuro for secrets)
      values-shared.yaml
      kubolt.yaml       # kubolt app/dependency/backup manifest
      AGENTS.md         # k3s stack docs
  thinkcentre/          # machine-specific infra for host `thinkcentre`
    AGENTS.md           # machine-level context
    README.md           # machine overview
    compose/            # Docker Compose stacks running on thinkcentre
      AGENTS.md         # compose stack conventions
      easyshell-runner/ # easyshell runner stack
```

Secrets config (`.obscuro/`) lives at the repo root so it can be shared across
machines and stacks.

## Adding a new machine or stack

Add a sibling `machines/<name>/` directory for a new host. Inside a machine,
add stack directories as needed, for example `k3s/`, `compose/`, `host/`, or
`terraform/`.

## Operating `pax`

See [`machines/pax/README.md`](machines/pax/README.md) for the machine overview
and [`machines/pax/k3s/AGENTS.md`](machines/pax/k3s/AGENTS.md) for k3s deploy,
backup, and operate instructions.

## Operating `thinkcentre`

See [`machines/thinkcentre/README.md`](machines/thinkcentre/README.md) for the machine overview
and [`machines/thinkcentre/compose/AGENTS.md`](machines/thinkcentre/compose/AGENTS.md) for compose
stack conventions.

## Tooling

k3s + Helm + [obscuro](https://github.com/janklabs/obscuro) for secrets.

- [kubolt](https://github.com/guneet-xyz/kubolt), Go CLI that wraps Helm for day-to-day cluster management (install, uninstall, validate, list, backup). Install with `curl -sSL https://raw.githubusercontent.com/guneet-xyz/kubolt/main/install.sh | sh`.
- Docker Compose + [obscuro](https://github.com/janklabs/obscuro) `inject` for host-Docker workloads on thinkcentre.

## Helm plugin caveat

If you previously installed the obscuro helm plugin from the old path, run `helm plugin remove obscuro` once before your next kubolt operation so Helm can use the current plugin path.
