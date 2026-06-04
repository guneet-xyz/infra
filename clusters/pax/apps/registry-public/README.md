# registry-public

Helm chart that deploys a public, read-only OCI container registry browser at
`cr.guneet.dev`. Anyone can browse repositories in CRUI without logging in, and
anonymous pulls are allowed without credentials. Writes are disabled.

Internally the chart runs `distribution/distribution:3` (the same engine as
the private registry at `cr.guneet.xyz`) plus CRUI. CRUI talks to an internal,
read-only registry API because CRUI does not implement Docker Bearer-token
challenge handling.

## Architecture

```
Browser https://cr.guneet.dev/              ──►  CRUI  ──►  internal read-only registry API
docker pull cr.guneet.dev/<repo>:<tag>      ──►  /v2/*  (anonymous pull)

docker push cr.guneet.dev/<repo>:<tag>      ──►  disabled
```

## Authentication

- **CRUI browsing** is public. No login required.
- **Pulls** are anonymous from a Docker client. No `docker login` required.
- **Pushes/deletes** are disabled by read-only registry configuration and the
  auth service grants no push scope.

## Anonymous pull

No credentials, no login:

```sh
docker pull cr.guneet.dev/<repo>:<tag>
```

## Operations

**Trigger garbage collection manually** (deletes layers unreferenced by any
manifest; does NOT delete untagged manifests automatically):

```sh
kubectl -n registry-public create job --from=cronjob/registry-public-gc gc-manual
kubectl -n registry-public logs -f job/gc-manual
```

The CronJob also runs automatically every Sunday at 04:00 UTC.

**List repositories with curl** (anonymous token flow):

```sh
token=$(curl -fsSL 'https://cr.guneet.dev/auth?service=cr.guneet.dev&scope=registry:catalog:*' | jq -r .token)
curl -H "Authorization: Bearer ${token}" https://cr.guneet.dev/v2/_catalog
```
