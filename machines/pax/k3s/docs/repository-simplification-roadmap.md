# Repository simplification roadmap

Goal: keep Kubernetes/k3s, but simplify this repository so it is easier to maintain, safer to change, and easier for agents to understand.

## Recommendation

Do not migrate the main `pax` stack to Docker Compose. Keep single-node k3s, Helm, kubolt, and Obscuro, but reduce bespoke chart/code duplication and improve repository context.

The target shape is a small productized Kubernetes platform, not 19 hand-maintained snowflake charts.

## Highest-impact changes

### 1. Split `machines/pax/k3s/AGENTS.md`

Current issue: `machines/pax/k3s/AGENTS.md` contains cluster overview, Helm conventions, networking, secrets, backups, Postgres library docs, and app conventions in one large file.

Target:

```text
machines/pax/k3s/
  AGENTS.md                  # 80-120 line quick context only
  docs/
    operations.md            # install, validate, backup, restore
    chart-conventions.md     # naming, probes, labels, nodeSelector
    networking.md            # public/private domains, NetworkPolicies
    secrets.md               # Obscuro workflow + secret inventory
    backup.md                # kubolt backup/restore rules
    app-catalog.md           # generated or maintained summary of apps
```

`AGENTS.md` should become the “read this first” file, not the entire manual.

### 2. Create a real shared Helm platform library

Current issue: there is a shared Postgres library, but common single-service app YAML is duplicated across charts.

Target:

```text
machines/pax/k3s/shared/platform/
  templates/
    _deployment.tpl
    _service.tpl
    _pvc.tpl
    _networkpolicy.tpl
    _secret.tpl
    _helpers.tpl
```

Use it for boring/common apps first:

- `ntfy`
- `openwebui`
- `zennotes`
- `demo`
- `walls`
- `litellm`
- `registry`
- `registry-public`

Keep bespoke charts where they are truly special:

- `caddy`
- `plane`
- `coturn`
- `tailscale`
- `synapse`

Common behavior to centralize:

- default-deny NetworkPolicy
- allow-from-Caddy NetworkPolicy
- standard Deployment shape
- readiness/liveness probes
- nodeSelector
- PVCs
- labels
- resource blocks

### 3. Introduce an app catalog as source of truth

Current issue: app identity and operations metadata are split across `kubolt.yaml`, `values-shared.yaml`, app `values.yaml`, Caddy templates, READMEs, and backup metadata.

Target:

```yaml
# machines/pax/k3s/apps.yaml
apps:
  litellm:
    namespace: litellm
    appName: litellm
    port: 4000
    exposure:
      public: llm.guneet.dev
      private: llm.guneet.xyz
    dependsOn: [caddy, registry]
    backup:
      - type: filesystem
        pvc: litellm-data
      - type: pg_dump
        podSelector: app=litellm-postgres
```

Initial version can be manually maintained. Later it can generate or validate `kubolt.yaml`, `values-shared.yaml`, route docs, and backup docs.

### 4. Move large inline Caddy routing to route data

Current issue: `caddy/templates/public-configmap.yaml` and `caddy/templates/private-configmap.yaml` embed route data directly inside Caddyfile templates.

Target:

```yaml
# caddy/values.yaml
routes:
  public:
    - host: walls.guneet.dev
      service: walls
    - host: llm.guneet.dev
      service: litellm
  private:
    - host: home.guneet.xyz
      service: homepage
    - host: notes.guneet.xyz
      service: zennotes
```

Keep special routes inline only where necessary:

- Matrix `.well-known`
- registry auth/write behavior
- Plane path routing
- raw Postgres TCP proxying

### 5. Standardize chart categories

Either reorganize directories or capture categories in `apps.yaml`.

Candidate categories:

```text
core:
  - caddy
  - registry
  - registry-public
  - tailscale

services:
  - litellm
  - openwebui
  - honcho
  - infisical
  - synapse
  - plane

tools:
  - homepage
  - headlamp
  - portainer
  - dev-db

experiments:
  - demo
  - zennotes
  - ntfy
```

The main point is to make app intent obvious.

## Code quality improvements

### 6. Remove avoidable drift

Known drift or likely drift patterns to check:

- README app counts can get stale.
- `dev-db/values.yaml` uses `kvqn/pgui:latest`, which violates the “no latest” production convention.
- Some secrets are documented as Obscuro-managed while values may still contain plain defaults.
- Many charts duplicate nearly identical NetworkPolicy, Service, PVC, and Deployment templates.

### 7. Add lightweight repository validation scripts

Keep `kubolt validate`, but add repo-specific checks:

```text
scripts/
  check-apps.sh             # kubolt.yaml entries match app directories
  check-values-shared.sh    # values-shared has app identity for every app
  check-no-latest.sh        # no imageTag: latest
  check-networkpolicy.sh    # every chart has networkpolicy.yaml unless exempt
  check-readmes.sh          # app counts/routes do not drift
```

CI should eventually run:

```sh
kubolt validate
scripts/check-apps.sh
scripts/check-no-latest.sh
```

### 8. Normalize labels

Current charts mostly use `app: name`. Keep that if needed for selectors, but add standard Kubernetes labels through shared helpers:

```yaml
app.kubernetes.io/name
app.kubernetes.io/instance
app.kubernetes.io/part-of: pax
app.kubernetes.io/managed-by: Helm
```

Do this through the shared library to avoid repetitive hand edits.

### 9. Reduce per-app README boilerplate

Most app READMEs repeat common commands such as:

```sh
kubolt install <app>
kubolt uninstall <app>
kubolt backup <app>
```

Move common commands to `docs/operations.md`.

Per-app READMEs should only include:

- what the app is
- URL/access mode
- special operational notes
- secret keys
- backup caveats
- dangerous footguns

## Agent context improvements

### 10. Add a short root `AGENTS.md`

Target root context:

```md
# infra agent context

This repo manages infrastructure by machine. `machines/pax/k3s` is the current single-node k3s stack.

Start here:
- machines/pax/AGENTS.md for machine context
- machines/pax/k3s/AGENTS.md for quick k3s stack context
- machines/pax/k3s/apps.yaml for app inventory
- machines/pax/k3s/kubolt.yaml for deploy/backup manifest
- machines/pax/k3s/docs/chart-conventions.md for Helm rules

Always validate with:
- kubolt validate from machines/pax/k3s
```

### 11. Add app-level context only for unusual apps

Most apps do not need their own `AGENTS.md`.

Add local context only for special apps:

```text
apps/caddy/AGENTS.md
apps/plane/AGENTS.md
apps/synapse/AGENTS.md
apps/coturn/AGENTS.md
```

These apps have special routing, upstream charts, federation, host networking, certs, or multi-component behavior.

## What not to do yet

- Do not switch to ArgoCD yet. It adds another control plane before the repo is cleaner.
- Do not merge everything into one huge umbrella chart. That hides app boundaries and makes partial operations harder.
- Do not abandon Helm for raw YAML. This repo already benefits from templating and dependencies.
- Do not convert every chart to a generic shared chart immediately. Start with boring apps first.

## Recommended execution order

1. Split docs and shrink `AGENTS.md`.
2. Add `apps.yaml` app catalog.
3. Add repo health checks for drift, `latest` tags, and missing policies.
4. Create `shared/platform` Helm library.
5. Migrate 3 boring charts first: `ntfy`, `openwebui`, `zennotes`.
6. Then migrate similar charts: `demo`, `registry`, `registry-public`, `walls`, `litellm`.
7. Leave special charts bespoke.

## Success criteria

- A new agent can understand the repo by reading root `AGENTS.md`, `machines/pax/AGENTS.md`, `machines/pax/k3s/AGENTS.md`, and `apps.yaml`.
- `kubolt validate` remains green after every step.
- App READMEs contain only app-specific information.
- Common chart patterns live in shared helpers, not copied across app charts.
- CI catches common drift before deployment.
