# walls

Wallpaper sharing platform. Deploys the walls app with its own PostgreSQL database.

## Install

From the `machines/pax/k3s/` directory:

```sh
kubolt install walls
```

## Upgrade

```sh
kubolt install walls
```

## Uninstall

```sh
kubolt uninstall walls
```

## Access

- Public: `https://walls.guneet.dev`

## Obscuro Secrets

| Key | Description |
|---|---|
| `WALLS_AUTH_SECRET` | Auth secret for magic link authentication |
| `SMTP_USERNAME` | SMTP auth username (shared) |
| `SMTP_PASSWORD` | SMTP auth password (shared) |
