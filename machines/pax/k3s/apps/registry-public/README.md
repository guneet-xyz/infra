# registry-public

Public OCI registry at `cr.guneet.dev`. Anonymous pulls and public CRUI browsing.
Pushes require credentials.

## Architecture

```
Browser https://cr.guneet.dev/              ──►  CRUI (public, no auth)
docker pull cr.guneet.dev/<repo>:<tag>      ──►  Caddy (no auth on GET)  ──►  registry /v2/*
docker push cr.guneet.dev/<repo>:<tag>      ──►  Caddy (basic_auth on POST/PUT/PATCH/DELETE)  ──►  registry /v2/*
```

## Authentication

- **CRUI browsing** is public. No login required.
- **Pulls** are anonymous. No `docker login` required.
- **Pushes and deletes** require `docker login` with the credentials in
  `REGISTRY_PUBLIC_USERNAME` / `REGISTRY_PUBLIC_PASSWORD`.

## Anonymous pull

```sh
docker pull cr.guneet.dev/<repo>:<tag>
```

## Authenticated push

```sh
USERNAME=$(obscuro get REGISTRY_PUBLIC_USERNAME)
PASSWORD=$(obscuro get REGISTRY_PUBLIC_PASSWORD)
echo "$PASSWORD" | docker login cr.guneet.dev -u "$USERNAME" --password-stdin
docker tag <local-image> cr.guneet.dev/<repo>:<tag>
docker push cr.guneet.dev/<repo>:<tag>
```

> **Note:** Caddy does not issue an HTTP 401 challenge on `GET /v2/`, so the
> Docker daemon may not persist credentials in `~/.docker/config.json`
> automatically. If `docker push` returns 401 unexpectedly, re-run
> `docker login` with `--password-stdin` immediately before the push.

## Operations

**Trigger garbage collection manually** (deletes layers unreferenced by any
manifest; does NOT delete untagged manifests automatically):

```sh
kubectl -n registry-public create job --from=cronjob/registry-public-gc gc-manual
kubectl -n registry-public logs -f job/gc-manual
```

The CronJob also runs automatically every Sunday at 04:00 UTC.

**List repositories with curl** (anonymous, no token):

```sh
curl -fsSL https://cr.guneet.dev/v2/_catalog
```

## Rotating the password

```sh
USERNAME="cr-pusher"
PASSWORD="$(openssl rand -base64 24 | tr -d '+/=' | cut -c1-32)"
HTPASSWD="$(htpasswd -nbB -C 14 "$USERNAME" "$PASSWORD" | cut -d: -f2)"
obscuro set REGISTRY_PUBLIC_USERNAME <<<"$USERNAME"
obscuro set REGISTRY_PUBLIC_PASSWORD <<<"$PASSWORD"
obscuro set REGISTRY_PUBLIC_HTPASSWD <<<"$HTPASSWD"
kubolt install caddy
```
