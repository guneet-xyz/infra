# synapse

Self-hosted Matrix homeserver ([Synapse](https://github.com/element-hq/synapse)) with the Element web client.

- **Server name**: `matrix.guneet.dev` (MXIDs: `@user:matrix.guneet.dev`)
- **Element web**: `https://chat.guneet.dev`
- **Federation**: enabled, open (all servers), via `:443` + `/.well-known/matrix/server` delegation
- **Registration**: closed; new users join via Admin-API-generated invite tokens

## Install

From `clusters/pax/`:

```sh
kubolt install synapse
```

After install, [create the initial admin user](#initial-admin-user).

## Upgrade

```sh
kubolt install synapse
```

## Uninstall

```sh
kubolt uninstall synapse
```

## Access

- Homeserver API: `https://matrix.guneet.dev`
- Element web: `https://chat.guneet.dev`

## Initial Admin User

After the first install, create the admin user:

```sh
kubectl -n synapse exec -it deploy/synapse -- \
  register_new_matrix_user \
    -c /config/homeserver.yaml \
    -u admin \
    -p '<choose-strong-password>' \
    -a \
    http://localhost:8008
```

## Invite-Token Registration

All non-admin signups require an invite token. Create one as admin:

```sh
# 1. Get admin access token (Settings → Help & About in Element, or via login API)
ACCESS_TOKEN=syt_...

# 2. Create a single-use token (valid 7 days)
curl -X POST 'https://matrix.guneet.dev/_synapse/admin/v1/registration_tokens/new' \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H 'Content-Type: application/json' \
  -d '{"uses_allowed": 1, "expiry_time": '$(($(date +%s) + 604800))'000}'
```

Share the `token` from the response. The recipient enters it during signup.

## Backups

```sh
kubolt backup synapse --dir ./backups
```

Produces:
- `synapse-postgres-<ts>.sql.gz`, full Synapse database dump
- `synapse-media-<ts>.tar.gz`, uploaded media files
- `synapse-data-<ts>.tar.gz`, Synapse local state

## ⚠️ Signing Key Safety

The signing key (`SYNAPSE_SIGNING_KEY` in Obscuro) is the server's permanent federation identity.
**Never regenerate it.** Losing it severs all federated rooms permanently.

Always include `.obscuro/secrets.json` in your backup strategy alongside the database.

## Known Limitations

- **No SMTP**: password reset via email is unavailable; admins reset passwords via the [Admin API](https://element-hq.github.io/synapse/latest/usage/administration/admin_api/index.html)
- **No SSO/OIDC**: password-only auth
- **No bridges**: no Discord/Slack/etc.
- **No TURN server**: voice/video calls limited to direct-reachable networks
- **No S3 media**: media stored on cluster PVC

## Obscuro Secrets

| Key | Description |
|---|---|
| `SYNAPSE_SIGNING_KEY` | ed25519 federation signing key (IMMUTABLE, never regenerate) |
| `SYNAPSE_POSTGRES_PASSWORD` | Postgres password for the `synapse` DB user |
| `SYNAPSE_REGISTRATION_SHARED_SECRET` | Shared secret for `register_new_matrix_user` admin CLI |
| `SYNAPSE_MACAROON_SECRET_KEY` | Key for issuing Matrix access tokens (rotating invalidates ALL sessions) |
| `SYNAPSE_FORM_SECRET` | Key for form-state CSRF tokens |
