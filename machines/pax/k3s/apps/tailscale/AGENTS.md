# tailscale

For general k3s/Helm conventions (chart structure, values layout, secrets, networking, backups), see `machines/pax/k3s/AGENTS.md`.

## Read this when

Any change to the tailscale chart, operator config, subnet routing, OAuth secrets, or any cluster service that is reachable only via Tailscale.

## What makes this chart non-standard

This chart is a thin wrapper around the upstream `tailscale-operator` Helm chart (version `1.96.5` from `https://pkgs.tailscale.com/helmcharts`), declared as a dependency in `Chart.yaml` and vendored under `charts/`. The wrapper adds two things:

1. A small `values.yaml` that supplies OAuth credentials and node selector for the operator.
2. A `Connector` custom resource that tells the operator to advertise a subnet route into the tailnet.

The operator itself manages its own CRDs (`Connector`, `ProxyClass`, etc.) and creates cluster-wide RBAC, plus child pods for each Connector/Proxy. It is not a normal single-Deployment app.

## appName discrepancy

In `values-shared.yaml`:

```yaml
apps:
  tailscale:
    appName: tailscale-operator
    namespace: tailscale
```

The camelCase key is `tailscale`, but `appName` is `tailscale-operator`. Resources created by the upstream operator chart use `tailscale-operator` as their Kubernetes name, so anything selecting by app label or service name must use `tailscale-operator`, not `tailscale`. This regularly confuses agents that assume `apps.tailscale.appName == tailscale`.

There is also no `port` field, because the operator does not expose a ClusterIP service to be reverse-proxied (see below).

## Connector

`templates/connector.yaml` ships a single `tailscale.com/v1alpha1` `Connector` named `tailnet-connector`:

```yaml
spec:
  subnetRouter:
    advertiseRoutes:
      - "100.64.0.0/10"
  tags:
    - "tag:k8s"
```

`100.64.0.0/10` is the CGNAT range that Tailscale itself uses for tailnet IPs. Advertising it makes the cluster a subnet router for the whole tailnet, so other Tailscale devices can reach any cluster service that lives on a Tailscale-assigned address through this Connector. The `tag:k8s` tag is what the upstream OAuth client is authorized to use, configured on the Tailscale admin side.

## OAuth secrets

The operator authenticates to Tailscale using OAuth client credentials, not a regular auth key:

- `TS_CLIENT_ID`
- `TS_CLIENT_SECRET`

Both come from Obscuro and are templated into `values.yaml` as `tailscale-operator.oauth.clientId` and `.clientSecret`. OAuth credentials do not have the same short expiry as standard Tailscale auth keys, but rotating the client secret requires redeploying the chart so the operator picks up the new value:

```sh
obscuro set TS_CLIENT_SECRET
kubolt install tailscale
```

## No kubolt backup

The operator is stateless. Tailscale device identity, ACLs, routes, and tags are all stored server-side in the tailnet, not in the cluster. There are no PVCs and no backup targets in `kubolt.yaml`.

## No service port

Unlike most apps in `values-shared.yaml`, `apps.tailscale` has no `port` field. The operator does not expose a ClusterIP service to be reverse-proxied. It connects outbound to the tailnet and announces routes from there, so caddy and other in-cluster clients never talk to it over a normal Kubernetes service.

## Cluster-wide blast radius

The upstream operator chart installs cluster-scoped RBAC so it can manage its own CRDs and create proxy pods in arbitrary namespaces. As a result, this chart has more reach than a typical app chart, and removing it has more impact:

- Uninstalling tailscale removes the `tailnet-connector` subnet route.
- Any cluster service reachable only via Tailscale (today: honcho) becomes unreachable from off-host clients.
- All operator-managed proxy pods elsewhere in the cluster will be torn down.

Treat `kubolt uninstall tailscale` as a maintenance event, not a routine action.

## Upgrade flow

The upstream chart is vendored, so upgrades are a two-step process:

1. Bump `version:` for the `tailscale-operator` dependency in `Chart.yaml`.
2. Refresh the vendored chart and lockfile:

   ```sh
   helm dependency update apps/tailscale
   ```

3. Commit the new `charts/tailscale-operator-<version>.tgz` and the updated `Chart.lock`.
4. Deploy:

   ```sh
   kubolt install tailscale
   ```

Always read the upstream release notes between versions before bumping; the operator's CRD schema and RBAC can change between minor releases.

## Validate

```sh
# From machines/pax/k3s/
kubolt validate

kubectl get pods -n tailscale
kubectl get connector tailnet-connector

# Confirm the 100.64.0.0/10 subnet route is approved and active
# in the Tailscale admin console (Machines → this node → Subnets).
```

## Do not

- Do not uninstall tailscale while Tailscale-only services (currently honcho) are in active use. There is no fallback ingress path.
- Do not change `advertiseRoutes` without checking which cluster services depend on Tailscale routing. Dropping `100.64.0.0/10` will silently break those services.
- Do not hardcode `appName: tailscale` in templates or NetworkPolicies. The real name is `tailscale-operator`, and it must be read from `values-shared.yaml` (`{{ .Values.apps.tailscale.appName }}`).
- Do not unvendor the upstream chart or switch to `--repo` style installs. Vendored `charts/*.tgz` plus `Chart.lock` is what keeps deploys reproducible.
- Do not treat `TS_CLIENT_ID` and `TS_CLIENT_SECRET` as auth keys. They are OAuth client credentials and must be rotated via the Tailscale admin OAuth client UI, not by issuing a new auth key.
