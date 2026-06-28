# demo

SSH reverse tunnel server for exposing local dev servers via
`demo.guneet.dev`. Run `ssh -NR 80:localhost:3000 demo` to make your
local port 3000 available at `https://demo.guneet.dev`.

Uses [linuxserver/openssh-server](https://hub.docker.com/r/linuxserver/openssh-server)
with the Tailscale operator exposing SSH as hostname `demo` on the Tailnet.

> For install/upgrade/uninstall and backup commands, see [`../../docs/operations.md`](../../docs/operations.md) and [`../../docs/backup.md`](../../docs/backup.md).

## Usage

```sh
# Forward local port 3000 to demo.guneet.dev
ssh -NR 80:localhost:3000 demo
```

## Obscuro Secrets

| Key | Description |
|---|---|
| `DEMO_SSH_AUTHORIZED_KEYS` | SSH public keys (one per line) for authorized access |
