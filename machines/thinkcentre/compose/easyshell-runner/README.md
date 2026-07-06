# easyshell-runner

easyshell runner — executes submission and terminal session jobs via the host Docker daemon; registers with the coordinator on pax over Tailscale.

## Prerequisites

1. Tailscale joined and coordinator reachable: `nc -zv coordinator.easyshell.sh 443`
2. Docker installed
3. Docker login to the private registry:
   ```sh
   obscuro get REGISTRY_USERNAME
   obscuro get REGISTRY_PASSWORD
   docker login cr.guneet.xyz
   ```
4. `obscuro` installed and master password stored: `obscuro auth store`
5. External Docker network created: `docker network create easyshell`
6. `EASYSHELL_COORDINATOR_REGISTRATION_TOKEN` already stored in Obscuro (set on pax before this step)

## Setup — first-time bootstrap

**Why two templates**: `.env.template` is bootstrap-safe (omits `RUNNER_ID`/`RUNNER_SECRET`) so the runner's bootstrap worker runs. `.env.runtime.template` is used after credentials are captured. Always use `--strict`.

1. Render the bootstrap-safe `.env` (omits RUNNER_ID / RUNNER_SECRET so the runner registers):
   ```sh
   obscuro inject --strict < .env.template > .env
   ```

2. Bootstrap the runner (registers with coordinator, prints credentials, exits):
   ```sh
   docker compose run --rm runner
   # stderr: BOOTSTRAP-ME: runner_id=... runner_secret=...
   ```

3. Capture the printed credentials into Obscuro. Run from the repo root:
   ```sh
   cd /path/to/infra
   obscuro set EASYSHELL_RUNNER_ID
   obscuro set EASYSHELL_RUNNER_SECRET
   cd machines/thinkcentre/compose/easyshell-runner
   ```

4. Render the runtime `.env` (now includes both RUNNER_ID and RUNNER_SECRET):
   ```sh
   obscuro inject --strict < .env.runtime.template > .env
   ```

5. Start the runner:
   ```sh
   docker compose up -d
   ```

6. Verify heartbeats:
   ```sh
   docker compose logs -f runner    # local, should show heartbeats
   # or on pax:
   kubectl -n easyshell exec deploy/easyshell-postgres -- \
     psql -U easyshell -d easyshell -c \
     "SELECT id, name, status, last_seen_at FROM easyshell_runner ORDER BY last_seen_at DESC;"
   ```

## Upgrade

```sh
obscuro inject --strict < .env.runtime.template > .env
docker compose pull
docker compose up -d
```

Runner state persists via `runner-data` volume; RUNNER_ID/RUNNER_SECRET reused from Obscuro.

## Rotate coordinator registration token

1. On pax (repo root): `obscuro set EASYSHELL_COORDINATOR_REGISTRATION_TOKEN` + `cd machines/pax/k3s && kubolt install easyshell`
2. On thinkcentre: `obscuro inject --strict < .env.runtime.template > .env && docker compose up -d`

## Rotate runner secret (if compromised)

1. `docker compose down`
2. `docker volume rm easyshell-runner_runner-data`
3. Follow the first-time bootstrap flow above (produces new RUNNER_ID/RUNNER_SECRET)

## Backup

None — runner SQLite is derived bootstrap state. `EASYSHELL_RUNNER_ID` and `EASYSHELL_RUNNER_SECRET` in Obscuro are the durable identity.

## Troubleshooting

- **`BOOTSTRAP-ME` printed and container exited** → normal on first bootstrap; proceed to step 3 above.
- **`unauthorized` in logs** → RUNNER_SECRET does not match coordinator's record. Verify in the coordinator DB or full re-bootstrap.
  ```sh
  kubectl -n easyshell exec deploy/easyshell-postgres -- psql -U easyshell -d easyshell -c "SELECT id, name FROM easyshell_runner;"
  ```
- **Runner not registering, no `BOOTSTRAP-ME`** → verify the .env was rendered from `.env.template` (bootstrap-safe, no RUNNER_ID):
  ```sh
  grep RUNNER_ID .env   # should return non-zero (absent)
  ```
- **Placeholder leaked into .env** → used `.env.runtime.template` before storing runner credentials AND dropped `--strict`. Always use `--strict`:
  ```sh
  grep "__EASYSHELL" .env   # should return non-zero (no leaked placeholders)
  ```
- **Runner cannot pull testcase images** → verify `DOCKER_REGISTRY` env, `docker login cr.guneet.xyz`, and that problem images were pushed by `release-problems.yml`.
- **Runner cannot reach coordinator** → `curl -v https://coordinator.easyshell.sh` from thinkcentre; verify tailscale status (`tailscale status`), pax caddy-private route, and `coordinator.easyshell.sh` DNS A record → 100.100.1.3.
