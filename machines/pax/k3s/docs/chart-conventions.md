# Chart Conventions

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

The namespace must match the chart directory name and the app entry in
`kubolt.yaml`.

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

Namespaces are created automatically by `kubolt install` via Helm's
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

## values-shared.yaml

Contains cross-app references and shared configuration. All charts are
installed with `-f values-shared.yaml` to merge these values.

### Cross-App References

When a chart references another app's service (e.g., a reverse proxy
routing to a backend), it uses `appName`, `namespace`, and `port` from
`values-shared.yaml` to derive the full service DNS name in templates.

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
