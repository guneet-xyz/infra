# thinkcentre

`thinkcentre` is a secondary machine that runs Docker Compose stacks for
workloads that need direct host Docker socket access (e.g., the easyshell
runner, which spawns containers to execute user code).

## Stacks

- [`compose/easyshell-runner/`](compose/easyshell-runner/) — easyshell runner
  stack. Registers with the coordinator on pax over Tailscale and executes
  submission jobs via the host Docker daemon.

Future stacks can live beside `compose/`, for example `host/` or
`k3s/`, without forcing every machine to use the same infrastructure
base.

## Operating compose stacks

Run compose commands from the stack directory (e.g. `compose/easyshell-runner`):

```sh
obscuro inject < .env.template > .env
docker compose config
docker compose pull
docker compose up -d
docker compose logs -f
```

See [`compose/AGENTS.md`](compose/AGENTS.md) for compose stack conventions and
each stack's `README.md` for setup, bootstrap, and upgrade details.
