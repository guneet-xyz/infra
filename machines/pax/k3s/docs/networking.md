# Networking

## Domain Convention

- `*.guneet.dev`, public services, routed through caddy-public
  (eth0 / `172.16.0.5`)
- `*.guneet.xyz`, private services, routed through caddy-private
  (tailscale0 / `100.100.1.3`)

This is a best-effort convention, not a strict rule.

## Network Policies

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

## Cross-Namespace Networking

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
