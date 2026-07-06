# Thinkcentre machine

This directory contains all infrastructure for the `thinkcentre` machine. Organize by
stack, not by cluster, so the machine can later host different infrastructure
bases side by side.

Current stacks:

- `compose/` — Docker Compose stacks managed with docker compose and Obscuro
  for secret injection into `.env` files.

When working on Docker Compose resources for `thinkcentre`, read
`compose/AGENTS.md` and validate with `docker compose config` before
bringing services up.
