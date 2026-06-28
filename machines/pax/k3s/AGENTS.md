# Pax k3s stack

This directory holds the k3s stack for the `pax` machine: Helm charts, shared
values, secrets placeholders, and the kubolt manifest that deploys and backs up
everything. If `pax` later runs another infrastructure base, add it as a
sibling stack under `machines/pax/`.

> **Note:** This tree moved from the old cluster-focused `clusters/pax/` path
> to `machines/pax/k3s/`. If Helm still references an old Obscuro plugin path,
> run `helm plugin remove obscuro` once before your next kubolt operation.

## Stack Structure

```
machines/pax/k3s/
├── AGENTS.md              # This file
├── kubolt.yaml            # App, dependency, namespace, and backup manifest
├── .gitignore             # Ignores backups/ directory
├── values-shared.yaml     # Cross-app references and shared config
├── shared/                # Shared Helm library charts
│   └── postgres/          # PostgreSQL library chart (type: library)
└── apps/                  # All Helm charts
    └── <chart>/
        ├── Chart.yaml
        ├── values.yaml
        ├── README.md
        └── templates/
```

Encrypted secrets live in the repo-root `.obscuro/` directory, not in this
stack directory.

Each subdirectory under `apps/` is a Helm chart. Subdirectories under
`shared/` are library charts that cannot be installed directly; they
provide reusable named templates that app charts depend on.

## App-level context

Most apps in `apps/` follow the standard k3s and Helm conventions described
in this file (chart structure, values layout, networking, secrets, backups)
and need no special context beyond it. When you touch one of those charts,
this file is the only context you need.

A small set of apps have behavior that is not captured by the general
conventions: cluster-wide networking, unusual secrets, host networking,
upstream chart wrappers, or admin surfaces. Those apps have their own
`AGENTS.md` next to the chart. Read it whenever you are touching that
chart's templates, values, or secrets.

Current unusual apps with chart-local context:

- `apps/caddy/AGENTS.md` — public/private routing, TLS, registry auth,
  Matrix well-known
- `apps/plane/AGENTS.md` — upstream chart, multi-service, special secrets
  and upgrade flow
- `apps/synapse/AGENTS.md` — Matrix federation, IMMUTABLE signing key,
  TURN coupling
- `apps/coturn/AGENTS.md` — host networking, host ports, Synapse
  `TURN_SHARED_SECRET` coupling
- `apps/tailscale/AGENTS.md` — upstream operator, subnet routing,
  cluster-wide networking
- `apps/infisical/AGENTS.md` — multi-component app, SMTP, encryption key
  safety
- `apps/honcho/AGENTS.md` — pgvector, deriver worker, LiteLLM coupling,
  psycopg3
- `apps/portainer/AGENTS.md` — cluster-admin RBAC, admin surface safety

## Detailed docs

Operational, chart, networking, secrets, and backup conventions live under
`docs/`. Read the file that matches the kind of change you are making:

- [`docs/operations.md`](docs/operations.md) — kubolt commands, prerequisites,
  bootstrap order, install/validate
- [`docs/chart-conventions.md`](docs/chart-conventions.md) — chart authoring
  rules: values layout, naming, labels, namespaces, node pinning, probes,
  shared library charts
- [`docs/networking.md`](docs/networking.md) — public/private domain
  convention, NetworkPolicy patterns, cross-namespace DNS
- [`docs/secrets.md`](docs/secrets.md) — Obscuro workflow, secrets inventory,
  shared SMTP config
- [`docs/backup.md`](docs/backup.md) — kubolt backup, restore, and adding new
  apps to backups
