# registry-public

Helm chart that deploys a public OCI container registry at `cr.guneet.dev`.
Anonymous pulls are allowed without credentials. Pushes require HTTP basic
auth backed by an htpasswd file.

Internally the chart runs `distribution/distribution:3` (the same engine as
the private registry at `cr.guneet.xyz`) with the htpasswd file mounted from
a Kubernetes secret. Pod restarts on credential rotation are triggered by a
checksum annotation on the secret.

## Architecture

```
docker pull cr.guneet.dev/<repo>:<tag>      ──►  /v2/*  (anonymous, no auth)

docker login cr.guneet.dev -u <user>        ──►  /v2/   (HTTP basic, htpasswd)
docker push cr.guneet.dev/<repo>:<tag>      ──►  /v2/*  (authenticated)
```

## Authentication

- **Pulls** are anonymous. No `docker login` required, no token, no header.
- **Pushes** require `docker login` with HTTP basic credentials.
- Two users live in the htpasswd file:
  - `admin` — break-glass / manual pushes from a workstation.
  - `ci` — used by GitHub Actions and other automation.

Credentials are stored bcrypt-hashed in the `registry-public-htpasswd`
secret. The source of truth is `.obscuro/secrets.json` (see *Managing users*
below).

## GitHub Actions push

Use [`docker/login-action`](https://github.com/docker/login-action) with
repository secrets `CR_USERNAME` (typically `ci`) and `CR_PASSWORD`:

```yaml
name: push-image
on:
  push:
    branches: [main]

jobs:
  push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Login to cr.guneet.dev
        uses: docker/login-action@v3
        with:
          registry: cr.guneet.dev
          username: ${{ secrets.CR_USERNAME }}
          password: ${{ secrets.CR_PASSWORD }}

      - name: Build and push
        run: |
          docker build -t cr.guneet.dev/${{ github.event.repository.name }}:${{ github.sha }} .
          docker push cr.guneet.dev/${{ github.event.repository.name }}:${{ github.sha }}
```

## Local push

From a workstation, log in once as `admin` (Docker caches the credential in
the OS keychain):

```sh
docker login cr.guneet.dev -u admin
# password prompt
docker push cr.guneet.dev/<repo>:<tag>
```

## Anonymous pull

No credentials, no login:

```sh
docker pull cr.guneet.dev/<repo>:<tag>
```

## Managing users

The htpasswd file is generated from `REGISTRY_PUBLIC_HTPASSWD` in
`.obscuro/secrets.json`. To add a user or rotate a password:

1. Generate a bcrypt-hashed entry (the `-n` flag prints to stdout instead of
   writing a file; `-B` selects bcrypt):

   ```sh
   htpasswd -nbB ci "$(openssl rand -base64 24)"
   # ci:$2y$05$...
   ```

   Capture both the plaintext password (store it in your password manager
   and/or the GitHub Actions secret) and the hashed line.

2. Update `REGISTRY_PUBLIC_HTPASSWD` in `.obscuro/secrets.json` so it
   contains one `user:hash` line per user (concatenate `admin` and `ci`).

3. Re-encrypt and commit:

   ```sh
   obscuro encrypt
   git add .obscuro/secrets.json.enc
   git commit -m "rotate registry-public ci credential"
   ```

4. Apply the chart. The pod restarts automatically because the deployment
   carries a checksum annotation over the htpasswd secret:

   ```sh
   helmfile -e pax -l name=registry-public apply
   ```

5. Update the `CR_PASSWORD` GitHub Actions secret in any repository that
   pushes to `cr.guneet.dev`.

Never commit plaintext passwords. `.obscuro/secrets.json` is the only place
the plaintext htpasswd lines live, and it is git-ignored; only the encrypted
`.obscuro/secrets.json.enc` is committed.

## Operations

**Trigger garbage collection manually** (deletes layers unreferenced by any
manifest; does NOT delete untagged manifests automatically):

```sh
kubectl -n registry-public create job --from=cronjob/registry-public-gc gc-manual
kubectl -n registry-public logs -f job/gc-manual
```

The CronJob also runs automatically every Sunday at 04:00 UTC.

**List repositories** (anonymous, no token required):

```sh
curl https://cr.guneet.dev/v2/_catalog
```
