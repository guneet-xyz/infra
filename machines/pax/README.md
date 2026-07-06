# pax

`pax` is the current single machine managed by this repo.

## Stacks

- [`k3s/`](k3s/) — single-node k3s stack with Helm charts, shared values,
  kubolt deployment metadata, Obscuro post-rendering, and PVC backup metadata.

Future stacks can live beside `k3s/`, for example `compose/`, `host/`, or
`terraform/`, without forcing every machine to use the same infrastructure
base.

## Operating k3s

Run kubolt commands from `machines/pax/k3s`:

```sh
kubolt validate
kubolt list
kubolt install <app>
kubolt backup --dir ./backups <app>
```

See [`k3s/AGENTS.md`](k3s/AGENTS.md) for the full k3s stack conventions.

## Other machines

See [`../thinkcentre/README.md`](../thinkcentre/README.md) for the
`thinkcentre` machine, which runs Docker Compose stacks (currently the
easyshell runner).
