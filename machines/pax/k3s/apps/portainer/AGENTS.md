# portainer agent context

[Portainer CE](https://www.portainer.io) is the cluster management UI
deployed privately at `portainer.guneet.xyz`. It is the only chart in the
stack that intentionally grants cluster-admin equivalent permissions to its
ServiceAccount, so treat it as a privileged admin surface.

For general k3s/Helm conventions (chart structure, values layout, secrets,
networking, backups), see `machines/pax/k3s/AGENTS.md`.

## Read this when

- Changing the portainer chart, RBAC, PVC, or access configuration
- Considering exposing portainer to a wider audience
- Upgrading the image or pinning the `imageTag`
- Uninstalling or reinstalling portainer (RBAC ordering matters)

## What makes this chart non-standard

`templates/rbac.yaml` defines a single `ClusterRole` with full wildcard
access:

```yaml
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
  - nonResourceURLs: ["*"]
    verbs: ["*"]
```

That role is bound via `ClusterRoleBinding` to the namespaced
`ServiceAccount` defined in `templates/serviceaccount.yaml`, which the
deployment runs as (`serviceAccountName`). The grant is intentional,
portainer is a cluster management UI and needs to inspect and mutate every
resource type. But it also means **any compromise of portainer = full
cluster compromise**. Treat the portainer namespace as cluster-admin.

## RBAC

Three resources in `templates/rbac.yaml` + `templates/serviceaccount.yaml`:

- `ServiceAccount` in the `portainer` namespace
- `ClusterRole` with wildcard rules above
- `ClusterRoleBinding` pointing the ClusterRole at the ServiceAccount

The role is intentionally permissive. Do not "tighten" it without
understanding which portainer features rely on which verbs, the upstream
Portainer agent UX depends on broad access.

## Access

- Private only: `portainer.guneet.xyz`, routed through caddy-private over
  Tailscale (`tailscale0` / `100.100.1.3`).
- Not exposed via caddy-public, and there is no `*.guneet.dev` route.
- Access is restricted to users on the Tailscale network. Anyone with
  Tailscale access to the cluster network can reach the UI.

## Persistent data

Portainer stores its configuration (users, endpoints, templates, stacks,
settings) in a single PVC:

- claim: `apps.portainer.claims.data` = `portainer-data`
- size: `apps.portainer.storage.data` = `1Gi`
- mount: `/data` inside the container

Losing this PVC means losing all portainer-managed config. Portainer
itself rebuilds its UI on restart (it talks to the live cluster via the
ClusterRole), but stored config (saved stacks, custom templates, user
accounts, registry creds entered through the UI) is gone.

## imageTag

`values.yaml` pins `image: portainer/portainer-ce` with `imageTag: lts`.
This is a known deviation from the "no latest, pin explicit versions"
convention used elsewhere in the stack. The `lts` tag is stable across
patch releases but is not an immutable pin, the image you pull today may
not be the image you pull tomorrow. When upgrading, bump to an explicit
version tag if you need reproducibility.

## No kubolt backup

The `portainer-data` PVC is intentionally not in `kubolt.yaml` backup
targets. The reasoning: portainer is a UI on top of the cluster, not a
source of truth, and most of what it shows is reconstructible from
live cluster state. Note that this means stored portainer stacks and
custom templates are not backed up; recreate them in code if you care
about preserving them.

## Validate

From `machines/pax/k3s/`:

```sh
kubolt validate
kubectl get pods -n portainer
```

Access via `https://portainer.guneet.xyz` (requires Tailscale).

## Footguns

- Exposing portainer publicly (e.g. by adding a caddy-public route or a
  `*.guneet.dev` hostname) makes the entire cluster reachable through it.
  Do not do this.
- The `lts` image tag is not pinned. A `kubectl rollout restart` can pull
  a different image digest than was last deployed. Pin an explicit version
  if you need reproducible deployments.
- Granting Tailscale access to a new user effectively grants them full
  cluster management through portainer, even if you only intended to give
  them access to a different private service.
- Deleting only the `ClusterRole` (or only the `ClusterRoleBinding`) while
  the other still exists can leave orphan bindings that block reinstalls,
  uninstall the whole chart with `kubolt uninstall portainer` rather than
  hand-deleting RBAC resources.

## Do not

- Do not expose portainer via caddy-public; keep it behind caddy-private
  and Tailscale only.
- Do not grant additional users Tailscale access without making sure they
  understand they gain full cluster management via portainer.
- Do not narrow the `ClusterRole` wildcard rules without first verifying
  every portainer feature you rely on still works.
- Do not delete the `ClusterRole` (or the `ClusterRoleBinding`) by hand
  before uninstalling portainer; orphaned bindings can block future
  installs. Use `kubolt uninstall portainer`.
- Do not move portainer to a different namespace without updating the
  `ClusterRoleBinding` subject; the binding references the namespaced
  ServiceAccount.
