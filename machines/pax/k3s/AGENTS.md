# K3s Infrastructure

## Repository Structure

```
machines/pax/k3s/
├── AGENTS.md              # This file
├── deploy.sh              # Install/upgrade/uninstall charts
├── validate.sh            # Validates all chart templates
├── .obscuro/              # Encrypted secrets (safe to commit)
├── values-shared.yaml     # Cross-app references and shared config
└── apps/                  # All Helm charts
    └── <chart>/
        ├── Chart.yaml
        ├── values.yaml
        ├── README.md
        └── templates/
```

Each subdirectory under `apps/` is a Helm chart.

## Prerequisites

- `helm` installed
- `kubectl` configured with cluster access
- [`obscuro`](https://github.com/janklabs/obscuro) installed
- `obscuro init` run in the repo (`.obscuro/` is at the repo root)
- `obscuro auth store` to save the master password in the OS keychain

## Bootstrap Order

Services must be installed in this order due to dependencies:

1. **caddy-public** — routes public traffic, no app dependencies
2. **registry** — hosts container images for custom apps
3. **apps** (walls, etc.) — depend on registry for images and caddy
   for routing

## Validation

Run `./validate.sh` from the `k3s/` directory to validate all charts. It
renders templates with `helm template`. Run this after any template or
values changes.

## Chart Conventions

### Template Syntax

Use standard Helm syntax: `{{ .Values.xxx }}`. Do not use `${{ }}`.

### Values Structure

All app values are nested under `apps.<camelCaseName>`. The camelCase key
is the app identifier; the `appName` field inside holds the actual
Kubernetes resource name (typically kebab-case).

Every chart's `values.yaml` must follow this structure:

```yaml
apps:
  <camelCaseName>:
    appName: <kebab-case-name>
    namespace: <namespace>
    images: ...
    replicas: ...
    claims: ...
```

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

## Secrets

Sensitive values (API tokens, passwords) must use Kubernetes Secrets, not
ConfigMaps.

### Naming

Secret names should be descriptive of their purpose, not prefixed with the
app name. Since each chart deploys into its own namespace, there is no risk
of collision. Examples:

- `app-secret` — main app secrets
- `postgres-secret` — database credentials
- `cloudflare-secret` — Cloudflare API token

### Obscuro

Secrets are managed with [Obscuro](https://github.com/janklabs/obscuro).
Encrypted secrets are stored in `.obscuro/secrets.json` and are safe to
commit. Obscuro acts as a Helm post-renderer, replacing `__KEY__`
placeholders in rendered manifests with decrypted values.

#### Workflow

```sh
# First time setup — store password in OS keychain
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
| `CLOUDFLARE_API_TOKEN` | caddy-public |
| `WALLS_AUTH_SECRET` | walls |
| `SMTP_USERNAME` | shared (all apps needing email) |
| `SMTP_PASSWORD` | shared (all apps needing email) |

## Shared Config

### values-shared.yaml

Contains cross-app references and shared configuration. All charts are
installed with `-f values-shared.yaml` to merge these values.

#### Cross-App References

When a chart references another app's service (e.g., a reverse proxy
routing to a backend), define it in `values-shared.yaml`:

```yaml
apps:
  <camelCaseName>:
    serviceName: <dns-name>
    port: <port>
```

#### Cross-Namespace Networking

Services in different namespaces must use the full Kubernetes DNS name:

```
<service>.<namespace>.svc.cluster.local
```

For example, caddy-public (in `caddy-public` namespace) reaching walls
(in `walls` namespace):

```yaml
apps:
  walls:
    serviceName: walls.walls.svc.cluster.local
    port: 3000
```

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
