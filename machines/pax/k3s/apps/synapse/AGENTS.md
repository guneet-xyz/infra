# synapse agent context

For general k3s/Helm conventions (chart structure, values layout, secrets,
networking, backups), see `machines/pax/k3s/AGENTS.md`.

## Read this when

Editing anything under `apps/synapse/`: the homeserver ConfigMap,
signing-key Secret, app Secret, Element web config, or synapse's entry
in `values-shared.yaml`. Synapse runs a Matrix homeserver with permanent
federation identity, so several secrets here are one-way (rotating them
is destructive) in ways the stack guide does not cover.

## ⚠️ IMMUTABLE signing key — never regenerate

`SYNAPSE_SIGNING_KEY` (Obscuro) is the ed25519 key that signs every
federation request this server makes. It IS the server's permanent
Matrix identity. **Never regenerate it.** It lands in the
`synapse-signing-key` Secret via `templates/signing-key-secret.yaml`
and is mounted at `/secrets/signing.key` (referenced from
`homeserver.yaml` as `signing_key_path`).

Losing or rotating this key has no graceful path:

- Every remote homeserver that federated with us caches our public key
  for the old signing key.
- A new key produces a new server fingerprint. Existing federated rooms
  cannot recover. Message history in those rooms is severed
  permanently.
- There is no "rotate signing key" admin command in Matrix. The only
  remedy is a new `server_name` (a new homeserver), which is itself
  permanent (see below).

**Always include `.obscuro/secrets.json` in every backup** alongside the
Postgres dump and the media PVC. The signing key cannot be regenerated
from cluster state.

## Architecture

The `synapse` namespace runs two apps:

- **Synapse server** (`ghcr.io/element-hq/synapse`) — the Matrix
  homeserver, port `8008` HTTP behind caddy-public's TLS.
- **Element web** (`vectorim/element-web`) — the web client.

Identities:

- `server_name`: `matrix.guneet.dev` (MXIDs are `@user:matrix.guneet.dev`)
- `public_baseurl`: `https://matrix.guneet.dev/`
- Element web at `chat.guneet.dev` (set as `web_client_location` in
  `homeserver.yaml`)

Postgres runs in-namespace via the shared postgres library
(`apps.synapse.postgres.*` in `values.yaml`).

## Federation coupling with caddy

Federation is enabled and open (`federation_domain_whitelist: null`)
over port 443 with `.well-known` delegation. The discovery endpoints
themselves are **served by caddy-public**, not by synapse:

- `https://matrix.guneet.dev/.well-known/matrix/server` →
  `{"m.server": "matrix.guneet.dev:443"}`
- `https://matrix.guneet.dev/.well-known/matrix/client` →
  `{"m.homeserver": {"base_url": "https://matrix.guneet.dev"}}`

These are static `respond` directives in
`apps/caddy/templates/public-configmap.yaml`. If you ever change the
federation port (currently `:443`) or the `server_name`, the fix must
touch **both** the caddy public Caddyfile **and** this chart's
`homeserver.yaml`. Update them together in the same change.

## TURN coupling with coturn

Voice/video calls go through coturn, and synapse authenticates against
it with a shared HMAC secret: `TURN_SHARED_SECRET` (Obscuro). It is
mounted into the synapse pod via the `app-secret` Secret
(`synapse-secret.yaml`) and referenced in `homeserver.yaml` as
`turn_shared_secret: ${TURN_SHARED_SECRET}`.

The same secret is consumed by the `coturn` chart. If you rotate
`TURN_SHARED_SECRET`, you **must** redeploy **both** apps in the same
rollout window:

```sh
obscuro set TURN_SHARED_SECRET
kubolt install coturn
kubolt install synapse
```

A mismatch silently breaks all TURN authentication and so all
non-direct-reachable calls.

## Registration: closed, invite-token only

`enable_registration: true` + `registration_requires_token: true` in
`homeserver.yaml`. New users cannot sign up without an admin-issued
token.

### Initial admin user

Run **once after the first install**, exec'ing into the running synapse
pod:

```sh
kubectl -n synapse exec -it deploy/synapse -- \
  register_new_matrix_user \
    -c /config/homeserver.yaml \
    -u admin \
    -p '<choose-strong-password>' \
    -a \
    http://localhost:8008
```

The `-a` flag promotes the new user to homeserver admin. The
`register_new_matrix_user` CLI authenticates with
`SYNAPSE_REGISTRATION_SHARED_SECRET` (Obscuro), mounted as an env var
from `app-secret`.

### Invite tokens via Admin API

Once an admin exists, create single-use tokens:

```sh
ACCESS_TOKEN=syt_...   # admin's access token, from Element or login API

curl -X POST 'https://matrix.guneet.dev/_synapse/admin/v1/registration_tokens/new' \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H 'Content-Type: application/json' \
  -d '{"uses_allowed": 1, "expiry_time": '$(($(date +%s) + 604800))'000}'
```

Share the returned `token` with the new user; they enter it during
signup.

## Backups — three targets

```sh
kubolt backup synapse --dir ./backups
```

Produces three artifacts, all required for a clean restore:

- **`synapse-postgres-<ts>.sql.gz`** — `pg_dump` of the Synapse
  database (user accounts, rooms, room state, access tokens, etc.).
- **`synapse-media-<ts>.tar.gz`** — the `synapse-media` PVC (uploaded
  files, avatars, attachments).
- **`synapse-data-<ts>.tar.gz`** — the `synapse-data` PVC (Synapse
  local state).

Plus, separately and critically, the repo-root `.obscuro/secrets.json`
must be in the same backup set (it holds `SYNAPSE_SIGNING_KEY`).
Without all four, a restore cannot reproduce the server.

## Key Obscuro secrets

| Key | Notes |
|---|---|
| `SYNAPSE_SIGNING_KEY` | **IMMUTABLE.** Permanent federation identity. Never regenerate. |
| `SYNAPSE_POSTGRES_PASSWORD` | Postgres password for the `synapse` DB user. Rotatable (update + redeploy). |
| `SYNAPSE_REGISTRATION_SHARED_SECRET` | Shared secret consumed by `register_new_matrix_user`. |
| `SYNAPSE_MACAROON_SECRET_KEY` | Signs Matrix access tokens. **Rotating logs out ALL active sessions** on every device for every user. |
| `SYNAPSE_FORM_SECRET` | Signs form-state CSRF tokens. |
| `TURN_SHARED_SECRET` | **Shared with coturn.** If rotated, redeploy both apps in the same window. |

## Validate

From `machines/pax/k3s/`:

```sh
kubolt validate
kubectl get pods -n synapse
curl -sf https://matrix.guneet.dev/_matrix/client/versions
```

The `client/versions` endpoint is unauthenticated and returns JSON when
synapse is healthy through caddy.

## Do not

- **Do not regenerate `SYNAPSE_SIGNING_KEY`** — ever. It severs all
  federated rooms permanently and there is no rollback.
- **Do not rotate `SYNAPSE_MACAROON_SECRET_KEY`** without explicit
  intent. Rotation invalidates every active access token in the
  database, logging out all users on all devices.
- **Do not change `server_name`** after federation has started. The
  Matrix protocol treats `server_name` as the homeserver's permanent
  identity; changing it produces a different homeserver, not a renamed
  one. Existing rooms, MXIDs, and federation cannot follow.
- **Do not rotate `TURN_SHARED_SECRET` without also redeploying
  coturn.** A mismatch silently breaks TURN authentication.
- **Do not back up the database without also backing up
  `.obscuro/secrets.json`.** A restore without the signing key cannot
  re-federate.
- **Do not update the federation port or `.well-known` payload in
  caddy without updating `homeserver.yaml` in the same change** (and
  vice versa). They must agree.
