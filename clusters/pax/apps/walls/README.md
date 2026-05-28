# walls

Wallpaper sharing platform. Deploys the walls app with its own PostgreSQL database.

## Install

From the `clusters/pax/` directory:

```sh
./deploy.sh walls install
```

## Upgrade

```sh
./deploy.sh walls upgrade
```

## Uninstall

```sh
./deploy.sh walls uninstall
```

## Access

- Public: `https://walls.guneet.dev`

## Obscuro Secrets

| Key | Description |
|---|---|
| `WALLS_AUTH_SECRET` | Auth secret for magic link authentication |
| `SMTP_USERNAME` | SMTP auth username (shared) |
| `SMTP_PASSWORD` | SMTP auth password (shared) |
