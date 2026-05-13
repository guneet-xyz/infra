# Migration from Shell Scripts to easyinfra

**Date:** May 2026
**Branch:** `feat/easyinfra-v2`

## Overview

This directory previously relied on three shell scripts (`deploy.sh`, `validate.sh`, `backup.sh`) to install, validate, and back up the k3s workloads on `pax`. Those scripts grew organically and duplicated logic across apps, made dependency ordering implicit, and offered no structured status, diff, or rollback.

We've migrated to [`easyinfra`](https://github.com/guneet-xyz/easyinfra), a single Go CLI that wraps Helm and the cluster operations in a consistent, declarative interface driven by `infra.yaml`. The shell scripts are kept in the repo for emergency rollback (see below) but should no longer be used for day-to-day operations.

## Command Mapping

Every script invocation has a direct `easyinfra` equivalent:

| Script | Invocation | easyinfra equivalent | Notes |
| --- | --- | --- | --- |
| deploy.sh | `deploy.sh <app> install` | `easyinfra k3s install <app>` | Install a single chart by name. |
| deploy.sh | `deploy.sh <app> upgrade` | `easyinfra k3s upgrade <app>` | Upgrade an existing release. |
| deploy.sh | `deploy.sh <app> uninstall` | `easyinfra k3s uninstall <app>` | Uninstall a release; PVCs are preserved. |
| deploy.sh | `deploy.sh --all install` | `easyinfra k3s install --all` | Install every chart discovered under apps/. |
| deploy.sh | `deploy.sh --all upgrade` | `easyinfra k3s upgrade --all` | Upgrade every installed release. |
| validate.sh | `validate.sh` | `easyinfra k3s ci validate` | Lint and template every chart for CI. |
| validate.sh | `validate.sh <app>` | `easyinfra k3s render <app>` | Render a single chart's manifests to stdout. |
| backup.sh | `backup.sh backup` | `easyinfra k3s backup run --all` | Snapshot every PVC across known apps. |
| backup.sh | `backup.sh backup <app>` | `easyinfra k3s backup run --app <app>` | Snapshot a single app's PVCs. |
| backup.sh | `backup.sh restore <app> latest` | `easyinfra k3s restore <app> --latest` | Restore the most recent snapshot for the app. |
| backup.sh | `backup.sh restore <app> <timestamp>` | `easyinfra k3s restore <app> --timestamp <ts>` | Restore a specific snapshot identified by timestamp. |
| backup.sh | `backup.sh list` | `easyinfra k3s backup list` | List available snapshots. |

The 11 managed apps remain the same: `caddy`, `demo`, `headlamp`, `homepage`, `infisical`, `litellm`, `openwebui`, `portainer`, `registry`, `tailscale`, `walls`.

## New Capabilities

`easyinfra` does everything the scripts did, plus a number of things they couldn't:

- **Topological ordering.** Dependencies declared in `infra.yaml` are respected automatically on install and upgrade; no more hand-ordered loops in `deploy.sh`.
- **Status, history, and rollback.** `easyinfra k3s status`, `easyinfra k3s history <app>`, and `easyinfra k3s rollback <app> <revision>` expose Helm release state and let you roll back a single app without touching the others.
- **Diff before apply.** `easyinfra k3s diff <app>` shows the rendered manifest delta between the current release and a pending change, so upgrades are no longer blind.
- **Doctor.** `easyinfra k3s doctor` runs preflight checks (kubectl reachable, Helm version, required namespaces, missing values files) before you deploy.
- **Discover.** `easyinfra k3s discover` walks `apps/` and reports any chart that isn't declared in `infra.yaml`, catching drift between filesystem and config.
- **Structured JSON output.** Every read-only command supports `--output json`, which makes scripting and CI assertions trivial.
- **Migrate explain.** `easyinfra k3s migrate explain` prints the command mapping above on demand, so the docs and the binary stay in sync.

## Configuration

All app and dependency declarations live in `infra.yaml` (v2 schema) at the root of this directory:

```
machines/pax/k3s/infra.yaml
```

The v2 format is a single document listing each app, its chart path, namespace, values files, and explicit `dependsOn` edges. The original v1 file is preserved as `infra.yaml.orig` for reference.

`easyinfra` reads `infra.yaml` from the current working directory by default; run it from `machines/pax/k3s/` or pass `--config` explicitly.

## Rollback Plan

The shell scripts (`deploy.sh`, `validate.sh`, `backup.sh`) are intentionally left in place. If `easyinfra` misbehaves and you need to fall back:

1. `cd /Users/guneet/projects/infra/machines/pax/k3s`
2. Run the script directly, e.g. `./deploy.sh caddy upgrade`.
3. The scripts continue to read the same `apps/` directory and chart layout, so they remain functional.

If we ever delete the scripts, they remain recoverable from git history on the `main` branch prior to the easyinfra cutover. Recover with:

```
git show main:machines/pax/k3s/deploy.sh > deploy.sh
git show main:machines/pax/k3s/validate.sh > validate.sh
git show main:machines/pax/k3s/backup.sh > backup.sh
chmod +x deploy.sh validate.sh backup.sh
```

For a complete operational rollback (revert `infra.yaml` v2 → v1, restore PVCs from snapshot), see `CUTOVER_RUNBOOK.md` in this directory.
