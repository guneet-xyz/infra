# Pax Cluster

This directory holds the configuration for the `pax` k3s cluster: Helm
charts, shared values, secrets, and the scripts that deploy and back up
everything. If you'd ever run a second cluster, you'd add a sibling
`clusters/<name>/` directory with the same shape.

> **Note:** This tree was moved from `machines/pax/k3s/`. If you previously
> installed the obscuro helm plugin from the old
> `machines/pax/k3s/plugins/obscuro` path, run `helm plugin remove obscuro`
> once; the next `./deploy.sh` will reinstall it from the new path
> automatically.

## Cluster Structure

```
clusters/pax/
├── AGENTS.md              # This file
├── deploy.sh              # Install/upgrade/uninstall charts
├── backup.sh              # Backup and restore PVC data
├── validate.sh            # Validates all chart templates
├── .gitignore             # Ignores backups/ directory
├── .obscuro/              # Encrypted secrets (safe to commit)
├── values-shared.yaml     # Cross-app references and shared config
├── shared/                # Shared Helm library charts
│   └── postgres/          # PostgreSQL library chart (type: library)
└── apps/                  # All Helm charts
    └── <chart>/
        ├── Chart.yaml
        ├── values.yaml
        ├── README.md
        └── templates/
```

Each subdirectory under `apps/` is a Helm chart. Subdirectories under
`shared/` are library charts that cannot be installed directly; they
provide reusable named templates that app charts depend on.

## Prerequisites

- `helm` installed
- `kubectl` configured with cluster access
- [`obscuro`](https://github.com/janklabs/obscuro) installed
- `obscuro init` run in the repo (`.obscuro/` is at the repo root)
- `obscuro auth store` to save the master password in the OS keychain
- Node labeled: `kubectl label node pax role=primary`
- **Calico** CNI installed (K3s must be started with
  `--flannel-backend=none --disable-network-policy`). Required for
  NetworkPolicy enforcement.

## Bootstrap Order

Services must be installed in this order due to dependencies:

1. **caddy**, routes public and private traffic, no app dependencies
2. **registry**, hosts container images for custom apps
3. **apps** (walls, headlamp, litellm, openwebui, etc.), depend on
   registry for images and caddy for routing

## Domain Convention

- `*.guneet.dev`, public services, routed through caddy-public
  (eth0 / `172.16.0.5`)
- `*.guneet.xyz`, private services, routed through caddy-private
  (tailscale0 / `100.72.80.23`)

This is a best-effort convention, not a strict rule.

## Validation

Run `./validate.sh` from this directory to validate all charts. It
renders templates with `helm template`. Run this after any template or
values changes.

## Chart Conventions

### Template Syntax

Use standard Helm syntax: `{{ .Values.xxx }}`. Do not use `${{ }}`.

### Values Structure

All app values are nested under `apps.<camelCaseName>`. The camelCase key
is the app identifier; the `appName` field inside holds the actual
Kubernetes resource name (typically kebab-case).

`appName`, `namespace`, and `port` are defined in `values-shared.yaml`
(the single source of truth for app identity and cross-app references).
Chart-level `values.yaml` files only contain chart-specific config
(images, replicas, claims, etc.).

`values-shared.yaml` structure:

```yaml
apps:
  <camelCaseName>:
    appName: <kebab-case-name>
    namespace: <namespace>
    port: <service-port>          # omit if not referenced by other charts
```

Chart-level `values.yaml` structure:

```yaml
apps:
  <camelCaseName>:
    images: ...
    replicas: ...
    claims: ...
```

Helm merges both files (`-f values-shared.yaml -f values.yaml`), so
templates access all fields under `.Values.apps.<camelCaseName>`.

The namespace must match the chart directory name. `deploy.sh` uses the
chart directory name as the Helm release namespace.

### Naming

Never hardcode resource names in templates. All names must come from
`.Values.apps.<camelCaseName>`:

- `apps.<name>.claims.*` for PersistentVolumeClaim names
- `apps.<name>.configMaps.*` for ConfigMap names
- `apps.<name>.images.<container>.image` and `.imageTag` for container
  images

Combine image fields in templates as:

```yaml
image: {{ .Values.apps.<name>.images.<container>.image }}:{{ .Values.apps.<name>.images.<container>.imageTag }}
```

Every container must have an explicit `name` field. Use a short,
descriptive name for the container's role (e.g., `caddy`, `postgres`,
`walls`), not the app name:

```yaml
containers:
  - name: caddy
```

### Labels

Every resource must have at minimum:

```yaml
metadata:
  labels:
    app: {{ .Values.apps.<name>.appName }}
```

Pod templates in Deployments must include matching labels so selectors
work:

```yaml
spec:
  selector:
    matchLabels:
      app: {{ .Values.apps.<name>.appName }}
  template:
    metadata:
      labels:
        app: {{ .Values.apps.<name>.appName }}
```

### Namespaces

Each chart deploys into its own namespace. Every resource must include:

```yaml
metadata:
  namespace: {{ .Values.apps.<name>.namespace }}
```

Namespaces are created automatically by `deploy.sh` via Helm's
`--create-namespace` flag. Do not include a `namespace.yaml` template in
charts.

### Node Pinning

All pods are pinned to the `primary` node using `nodeSelector`. This
ensures all workloads run on the same node, which is required for shared
RWO PVCs and interface-bound services.

For our own templates:

```yaml
spec:
  template:
    spec:
      nodeSelector:
        role: primary
```

For upstream umbrella charts (e.g., headlamp), set `nodeSelector` in
the chart's values:

```yaml
headlamp:
  nodeSelector:
    role: primary
```

Prerequisite: `kubectl label node pax role=primary`

### Deployment Strategy

Use `RollingUpdate` by default with zero-downtime settings:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0
    maxSurge: 1
```

Use `Recreate` only for single-writer databases (e.g., PostgreSQL) where
two instances must never run simultaneously against the same data
directory.

### Health Probes

Every container must have readiness and liveness probes. These are
required for rolling updates to work correctly; Kubernetes needs to know
when a new pod is ready before killing the old one.

For HTTP services:

```yaml
readinessProbe:
  httpGet:
    path: /
    port: <port>
  initialDelaySeconds: 5
  periodSeconds: 5
livenessProbe:
  httpGet:
    path: /
    port: <port>
  initialDelaySeconds: 15
  periodSeconds: 10
```

For databases, use command-based probes (e.g., `pg_isready` for
PostgreSQL).

### Network Policies

Every chart must include a `templates/networkpolicy.yaml` with:

1. A **default deny** policy that blocks all ingress to the namespace
2. **Explicit allow** policies for each legitimate traffic flow

Policies use `namespaceSelector` with the automatic
`kubernetes.io/metadata.name` label to match source namespaces. Use
`podSelector` within the same namespace to scope access (e.g., only
the app pod can reach its Postgres, not other pods in the namespace).

Egress is left open (not restricted) to avoid complexity with DNS
resolution, external API calls, and SMTP.

Standard patterns:

```yaml
# Default deny, every chart must have this
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: {{ .Values.apps.<name>.namespace }}
spec:
  podSelector: {}
  policyTypes:
    - Ingress
---
# Allow from Caddy, most app charts need this
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-caddy
  namespace: {{ .Values.apps.<name>.namespace }}
spec:
  podSelector:
    matchLabels:
      app: {{ .Values.apps.<name>.appName }}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: {{ .Values.apps.caddy.namespace }}
      ports:
        - port: {{ .Values.apps.<name>.port }}
          protocol: TCP
---
# Allow app to reach its Postgres, charts using the postgres library
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-postgres
  namespace: {{ .Values.apps.<name>.namespace }}
spec:
  podSelector:
    matchLabels:
      app: {{ .Values.apps.<name>.postgres.serviceName }}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: {{ .Values.apps.<name>.appName }}
      ports:
        - port: {{ .Values.apps.<name>.postgres.port }}
          protocol: TCP
```

**Prerequisite:** Calico must be installed as the CNI. K3s's default
Flannel CNI does not enforce NetworkPolicies.

## Secrets

Sensitive values (API tokens, passwords) must use Kubernetes Secrets, not
ConfigMaps.

### Naming

Secret names should be descriptive of their purpose, not prefixed with the
app name. Since each chart deploys into its own namespace, there is no risk
of collision. Examples:

- `app-secret`, main app secrets
- `postgres-secret`, database credentials
- `cloudflare-secret`, Cloudflare API token

### Obscuro

Secrets are managed with [Obscuro](https://github.com/janklabs/obscuro).
Encrypted secrets are stored in `.obscuro/secrets.json` and are safe to
commit. Obscuro acts as a Helm post-renderer, replacing `__KEY__`
placeholders in rendered manifests with decrypted values.

#### Workflow

```sh
# First time setup, store password in OS keychain
obscuro auth store

# Store a secret
obscuro set SECRET_KEY

# List all secret names
obscuro list

# Deploy with post-renderer (password retrieved from keychain automatically)
./deploy.sh <chart> install
```

Obscuro resolves the password in this order:
1. `--password` / `-p` flag
2. OS keychain (macOS Keychain / Linux Secret Service)
3. `OBSCURO_PASSWORD` environment variable
4. Interactive TTY prompt

#### Placeholder Convention

In Secret templates, use `__KEY__` placeholders for sensitive values:

```yaml
stringData:
  API_TOKEN: __API_TOKEN__
```

Non-sensitive config (database names, ports, hostnames) can use regular
Helm values.

#### Current Secrets

| Key | Used by |
|---|---|
| `CLOUDFLARE_API_TOKEN` | caddy |
| `WALLS_AUTH_SECRET` | walls |
| `WALLS_POSTGRES_PASSWORD` | walls (postgres) |
| `SMTP_USERNAME` | shared (walls, litellm, infisical) |
| `SMTP_PASSWORD` | shared (walls, litellm, infisical) |
| `GITHUB_API_KEY` | litellm |
| `GITHUB_MODELS_API_KEY` | litellm (GitHub Models embeddings) |
| `LITELLM_MASTER_KEY` | litellm |
| `LITELLM_POSTGRES_PASSWORD` | litellm (postgres) |
| `INFISICAL_AUTH_SECRET` | infisical |
| `INFISICAL_ENCRYPTION_KEY` | infisical |
| `INFISICAL_DB_CONNECTION_URI` | infisical |
| `INFISICAL_POSTGRES_PASSWORD` | infisical (postgres) |
| `REGISTRY_HTPASSWD` | registry |
| `REGISTRY_USERNAME` | registry-ui |
| `REGISTRY_PASSWORD` | registry-ui |
| `REGISTRY_SESSION_SECRET` | registry-ui |
| `TS_CLIENT_ID` | tailscale |
| `TS_CLIENT_SECRET` | tailscale |
| `DEMO_SSH_AUTHORIZED_KEYS` | demo (SSH public keys, one per line) |

## Shared Config

### values-shared.yaml

Contains cross-app references and shared configuration. All charts are
installed with `-f values-shared.yaml` to merge these values.

#### Cross-App References

When a chart references another app's service (e.g., a reverse proxy
routing to a backend), it uses `appName`, `namespace`, and `port` from
`values-shared.yaml` to derive the full service DNS name in templates.

#### Cross-Namespace Networking

Services in different namespaces must use the full Kubernetes DNS name,
derived from shared values:

```
{{ .Values.apps.<name>.appName }}.{{ .Values.apps.<name>.namespace }}.svc.cluster.local
```

For example, caddy reaching walls:

```
{{ .Values.apps.walls.appName }}.{{ .Values.apps.walls.namespace }}.svc.cluster.local:{{ .Values.apps.walls.port }}
```

Never hardcode full service DNS names in values or templates.

#### Shared SMTP Config

Non-sensitive SMTP configuration is in `values-shared.yaml` under `smtp`:

```yaml
smtp:
  host: <smtp-host>
  port: "587"
  mailFrom: <sender-email>
```

SMTP credentials (`SMTP_USERNAME`, `SMTP_PASSWORD`) are Obscuro secrets.

## Installing a Chart

Use `deploy.sh` to install, upgrade, or uninstall charts. It automatically
reads the namespace from the chart's `values.yaml` and passes the correct
flags to Helm.

```sh
./deploy.sh <chart> install
./deploy.sh <chart> upgrade
./deploy.sh <chart> uninstall
```

The script handles `-n <namespace> --create-namespace`, merging
`values-shared.yaml`, and the Obscuro post-renderer.

See each chart's `README.md` for additional details.

## Backups

Use `backup.sh` to back up and restore PVC data. The script SSHes into
pax, tars each PVC's host directory, and SCPs the archives to the local
host under `backups/<timestamp>/`. During backup and restore, all
deployments in the app's namespace are scaled to zero and restored to
their original replica counts afterward.

```sh
./backup.sh backup                            # all apps
./backup.sh backup walls                      # specific app
./backup.sh restore walls                     # restore from latest backup
./backup.sh restore litellm -- 2026-04-24_143000  # restore specific timestamp
```

### Adding a New App to Backups

Edit `backup.sh` and add the app's PVCs to the `pvcs_for_app` function
and `ALL_APPS` list.

### Restore After Data Loss

If PVCs were deleted (e.g., after `helm uninstall`), reinstall the chart
first with `deploy.sh <chart> install` to recreate the PVCs, then run
`backup.sh restore <app>`. The script resolves PVC host paths dynamically.

## Shared Library Charts

Library charts live under `shared/` and provide reusable templates. They
have `type: library` in their `Chart.yaml` and cannot be installed
directly.

### Postgres Library (`shared/postgres`)

Provides named templates for a standard PostgreSQL sidecar: deployment,
service, secret, and PVC. App charts depend on it via:

```yaml
# Chart.yaml
dependencies:
  - name: postgres
    version: ">=0.1.0"
    repository: file://../../shared/postgres
```

After adding the dependency, run `helm dependency update` to pull it in.

Templates are invoked with `include`, passing the app's values:

```yaml
{{ include "postgres.deployment" (dict "app" .Values.apps.<name>) }}
```

Available templates: `postgres.deployment`, `postgres.service`,
`postgres.secret`, `postgres.pvc`.

The calling chart's `values.yaml` must provide these fields under
`apps.<name>`:

```yaml
images:
  postgres:
    image: postgres
    imageTag: "17.9"
postgres:
  serviceName: <app>-postgres
  port: 5432
  dbName: <db>
  dbUser: <user>
  dbPassword: <password>   # will be moved to Obscuro
  storage: 1Gi             # use 1Gi for new charts
claims:
  postgresData: <app>-postgres-data
```
