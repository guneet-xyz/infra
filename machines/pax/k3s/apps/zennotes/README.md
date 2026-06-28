# zennotes

ZenNotes — keyboard-first Markdown notes web app with Vim motions.
Self-hosted Go server serving an embedded web bundle.

Upstream: https://github.com/ZenNotes/zennotes

## Install

From the `machines/pax/k3s/` directory:

```sh
kubolt install zennotes
```

## Upgrade

```sh
kubolt install zennotes
```

## Uninstall

```sh
kubolt uninstall zennotes
```

## Access

- Private: `https://notes.guneet.xyz`

## Notes

- Auth is disabled (`ZENNOTES_ALLOW_INSECURE_NOAUTH=1`); access is gated by Tailscale ACLs and Calico NetworkPolicy.
- Single-replica only (in-memory file watcher); upgrades use `Recreate` strategy and incur a brief 502 window.
- Vault hard-locked to `/workspace`; the picker is disabled.
- PVC deletion on `kubolt uninstall` deletes the vault content irreversibly. Always `kubolt backup zennotes` before uninstalling.
