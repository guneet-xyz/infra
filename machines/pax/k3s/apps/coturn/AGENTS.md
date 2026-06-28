# coturn

For general k3s/Helm conventions (chart structure, values layout, secrets, networking, backups), see `machines/pax/k3s/AGENTS.md`.

## Read this when

Any change to coturn's chart, values, secrets, or TURN server config. Also read this before touching Synapse's TURN settings, since the two apps share a secret that kubolt does not track.

## What makes this chart non-standard

coturn is not a normal ClusterIP web app. The Deployment sets:

- `hostNetwork: true`
- `dnsPolicy: ClusterFirstWithHostNet`

The pod binds directly to the host network stack so it can receive raw UDP traffic on host ports. NetworkPolicies still apply (the chart ships a default-deny plus explicit allow rules for the TURN ports), but the underlying network model is fundamentally different from a normal Kubernetes service. There is no ClusterIP and no Service object: clients reach coturn through the host's public IP, not through cluster DNS.

The pod is pinned to the `primary` node via `nodeSelector: role: primary`, and the Deployment uses `strategy: Recreate` because the host ports cannot be bound twice during a rollout.

## Host ports

All ports are bound as `hostPort` directly on the primary node. They must be open on the host firewall:

| Purpose | Port | Protocols |
|---|---|---|
| STUN/TURN | 3478 | UDP + TCP |
| TURNS (TLS) | 5349 | UDP + TCP |
| Relay range | 49160-49200 | UDP |

The relay range comes from `apps.coturn.relayPortMin` and `apps.coturn.relayPortMax` in `values.yaml` and is also reflected in the NetworkPolicy `allow-turn-relay-range` rule.

## External IP

`apps.coturn.externalIp` is hardcoded to `20.219.12.93` in `values.yaml`. This is the public IP of the host and is injected into `turnserver.conf` as `external-ip` so coturn advertises the correct address in TURN allocation responses. If the host's public IP changes, update `apps.coturn.externalIp` and reinstall the chart.

## Realm

`apps.coturn.realm` is `matrix.guneet.dev`. The realm must match Synapse's `turn_uris` configuration. Changing the realm without updating Synapse will break Matrix A/V calls.

## TLS certificates

coturn reads its TLS certs from a `hostPath` volume that points directly into the caddy PVC directory on the node filesystem:

```
/var/lib/rancher/k3s/storage/pvc-e8515c4e-a34d-4722-ae35-1eb83d612842_caddy_caddy-data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/turn.matrix.guneet.dev
```

The path is hardcoded as `apps.coturn.caddyCertsHostPath` in `values.yaml`. The container mounts it read-only at `/certs` and `turnserver.conf` references `/certs/turn.matrix.guneet.dev.crt` and `/certs/turn.matrix.guneet.dev.key`.

If the caddy PVC is ever recreated, or k3s changes its local storage layout, the UUID in this path changes and the volume mount will point at a non-existent directory. The path must be updated to match the new caddy PVC storage path before coturn will start.

## Synapse coupling (not in kubolt.yaml dependencies)

coturn and synapse share the `TURN_SHARED_SECRET` Obscuro secret. coturn injects it into `turnserver.conf` as `static-auth-secret`, and Synapse signs short-lived TURN credentials with the same value. This is a runtime dependency, not a Helm dependency.

`kubolt.yaml` does not track this coupling. If you rotate `TURN_SHARED_SECRET` in Obscuro, you must redeploy both charts manually, in this order:

1. `kubolt install coturn`
2. `kubolt install synapse`

Until both pods restart with the new secret, Matrix A/V calls will fail authentication.

## Config generation

`turnserver.conf` is not rendered directly into a ConfigMap. The ConfigMap `coturn-config` holds a template, and an init container (`config-subst`, alpine + `envsubst`) substitutes three variables at pod startup:

- `TURN_SHARED_SECRET` from the `coturn-secret` Secret
- `REALM` from `apps.coturn.realm`
- `EXTERNAL_IP` from `apps.coturn.externalIp`

The rendered config is written into an `emptyDir` volume at `/config/turnserver.conf`, which is then mounted into the coturn container.

## No kubolt backup

coturn has no PVC and no backup target in `kubolt.yaml`. It is stateless: all persistent Matrix state lives in Synapse's Postgres. Reinstalling coturn is safe and loses nothing.

## Validate

```sh
# Render and lint all charts
kubolt validate

# From machines/pax/k3s/
kubectl get pods -n coturn
kubectl describe pod -n coturn -l app=coturn

# Optional: test TURN connectivity from outside the cluster
turnutils_uclient -v -t -u <user> -w <pass> 20.219.12.93

# End-to-end: place a Matrix A/V call between two clients and confirm
# media flows via the TURN server
```

## Do not

- Do not change `hostNetwork: true` to `false`. coturn requires the host network for TURN relay; without it, clients cannot reach the relay ports.
- Do not change the host ports (3478, 5349, 49160-49200) without also updating the host firewall rules and any clients/Synapse config that reference them.
- Do not change `apps.coturn.caddyCertsHostPath` without first verifying the new caddy PVC storage path exists on the node filesystem and contains the expected cert/key files.
- Do not rotate `TURN_SHARED_SECRET` without redeploying Synapse afterwards. Matrix A/V calls will silently fail until both pods share the new secret.
- Do not add coturn to `kubolt.yaml` backup targets. There is no state to back up.
