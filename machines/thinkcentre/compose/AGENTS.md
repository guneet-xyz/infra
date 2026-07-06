# thinkcentre compose stacks

## Stack layout

Every compose stack lives under `compose/<stack-name>/` and contains:

- `compose.yml` — Docker Compose service definitions
- `.env.template` — committed; uses `__KEY__` placeholders for Obscuro-managed
  secrets; plain `key=value` for non-secrets
- `.env.runtime.template` — committed (for stacks with post-bootstrap
  credentials); same shape but includes runtime secrets
- `.env` — gitignored; rendered output, never committed
- `README.md` — setup, bootstrap, upgrade, rotate, and troubleshooting
  instructions

## Secrets via Obscuro inject

Secrets come from the repo-root `.obscuro/secrets.json` (shared with pax k3s).
Render the `.env` before any compose operation:

```sh
obscuro inject --strict < .env.template > .env
```

For stacks that have a runtime template (post-bootstrap credentials):

```sh
obscuro inject --strict < .env.runtime.template > .env
```

Always use `--strict` to fail fast if any placeholder is missing from the
Obscuro store. Without `--strict`, missing keys are left as literal strings
(e.g., `RUNNER_ID=__EASYSHELL_RUNNER_ID__`), which can cause silent auth
failures.

Use `obscuro get KEY` to retrieve individual values, and `obscuro set KEY` to
add or rotate them.

## Docker login prereq

Every thinkcentre host must authenticate against the private registry before
pulling images:

```sh
docker login cr.guneet.xyz
# credentials from:
obscuro get REGISTRY_USERNAME
obscuro get REGISTRY_PASSWORD
```

## External networks

Stacks that need cross-service communication use an external Docker network.
Create it once before the first `docker compose up`:

```sh
docker network create easyshell
```

## Restart policy

All services use `restart: unless-stopped`. Docker's daemon starts them on
reboot without a systemd unit.

No watchtower, no auto-upgrade automation. Upgrade flow:

```sh
docker compose pull
docker compose up -d
```

## First-time setup sequence

1. Install obscuro and run `obscuro auth store` to save the master password in
   the OS keychain
2. Clone the infra repo
3. Set required Obscuro secrets (`obscuro set KEY` from the stack's README)
4. Create any required external networks
5. Render `.env` with `obscuro inject --strict`
6. Follow the stack README for service-specific bootstrap (e.g., runner
   first-boot registration)
