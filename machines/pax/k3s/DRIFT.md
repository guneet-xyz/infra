# Expected Drift

This document explains the differences shown by `easyinfra k3s diff --all` between the chart templates and the live cluster state. All drift listed here is **expected and intentional** — no action required.

## caddy — cloudflare-secret

**Diff**: `CLOUDFLARE_API_TOKEN` byte count differs (40 bytes live vs 24 bytes in chart template).

**Reason**: The chart template contains a placeholder value for `CLOUDFLARE_API_TOKEN`. The real secret is managed outside of Helm (injected via Infisical or manually). The live cluster has the real token; the chart has a dummy value. This is by design — secrets are not stored in the chart.

**Action**: None. The secret is managed externally.

## demo — ssh-secret

**Diff**: `authorized_keys` byte count differs (585 bytes live vs 28 bytes in chart template).

**Reason**: Same as above — the chart template contains a placeholder `authorized_keys` value. The real authorized_keys are injected externally. The live cluster has the real keys.

**Action**: None. The secret is managed externally.

## homepage — Deployment checksum/config annotation

**Diff**: `checksum/config` annotation differs between live cluster and rendered template.

**Reason**: The checksum is computed from the homepage ConfigMap contents. The live cluster's ConfigMap was last updated at a different time than the current chart template. This is a normal drift that occurs whenever the homepage configuration is updated — the checksum reflects the current ConfigMap state.

**Action**: None. The next `easyinfra k3s upgrade homepage` will reconcile this by recomputing the checksum from the current values.

## Summary

| App | Resource | Drift Type | Action |
|-----|----------|------------|--------|
| caddy | cloudflare-secret (Secret) | External secret placeholder | None |
| demo | ssh-secret (Secret) | External secret placeholder | None |
| homepage | Deployment | Config checksum annotation | None (reconciles on next upgrade) |

All other apps (headlamp, infisical, litellm, openwebui, portainer, registry, tailscale, walls) show **no diff** — they are in sync with the live cluster.
