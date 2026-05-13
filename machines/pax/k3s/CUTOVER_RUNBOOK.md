# Cutover Runbook: Legacy Script Removal

> **Manual operator action required. Do NOT execute as part of the plan.**

This runbook covers the final cutover from the legacy bash scripts (`deploy.sh`,
`validate.sh`, `backup.sh`) to the `easyinfra` tooling. It is intentionally
manual: the scripts have lived in this tree for a long time and removing them
deserves a deliberate operator decision rather than an automated migration step.

## Pre-flight Checklist

Run through every item below before deleting anything. If any item fails, stop
and investigate.

- [ ] `easyinfra ci validate` passes locally against the current `infra.yaml`
- [ ] The `easyinfra-validate.yml` GitHub Actions workflow has been green on
      `main` for at least one full week
- [ ] At least one stable week of parallel operation (both legacy scripts and
      `easyinfra` available, no drift complaints from operators)
- [ ] A fresh backup has been taken via `./backup.sh` and stored off-host
- [ ] The cluster is healthy: `kubectl get nodes` and `kubectl get pods -A`
      show no unexpected `NotReady` / `CrashLoopBackOff`
- [ ] `DRIFT.md` has been reviewed; any documented drift is intentional
- [ ] The team has been notified in `#infra` (or equivalent) at least 24h ahead
- [ ] An operator is available on-call for the next 24h after cutover

## Deletion Order

Delete the scripts one at a time, in this order, committing each removal as a
separate commit so revert is surgical.

1. **`validate.sh` first.** CI now uses `easyinfra ci validate`, so this script
   is already redundant in practice. Removing it first proves the workflow is
   self-sufficient without breaking deploy or backup paths.
2. **`deploy.sh` second.** Once validation has been gone for a few days with no
   issues, retire deploy. `easyinfra apply` is the replacement. Watch the next
   apply closely.
3. **`backup.sh` last.** Backups are the highest-blast-radius script: if the
   replacement is wrong, you lose recovery capability. Keep this around until
   the new backup path has produced at least two successful restorable
   snapshots.

After each deletion, run the post-cutover verification section before moving on
to the next script.

## AGENTS.md Update

Update `machines/pax/k3s/AGENTS.md` to point operators at `easyinfra` instead
of the legacy scripts. The exact diff:

```diff
-## Deploy
-Run `./deploy.sh` to apply Helm charts to the cluster.
+## Deploy
+Run `easyinfra apply` from the repo root. The legacy `deploy.sh` has been
+removed; see git history if you need the old behaviour.

-## Validate
-Run `./validate.sh` to check chart syntax before committing.
+## Validate
+Run `easyinfra ci validate`. CI runs the same command on every PR.

-## Backup
-Run `./backup.sh` to snapshot cluster state to `./backups/`.
+## Backup
+Run `easyinfra backup` to snapshot cluster state. Output location is
+configured in `infra.yaml` under `backup.destination`.
```

Commit this change in the same PR as the final script deletion so the
documentation never lies about what's available on disk.

## Rollback Procedure

If anything goes wrong after a deletion, roll back the offending commit:

```bash
# Identify the commit that removed the script
git log --oneline -- machines/pax/k3s/<script>.sh

# Revert it (creates a new commit that restores the file)
git revert <sha>

# Push and confirm the file is back
git push
ls machines/pax/k3s/<script>.sh
```

Because each script was deleted in its own commit, you can roll back the
problematic one without resurrecting the others. Once reverted, run the script
to confirm it still works, then file an issue describing what failed in the
`easyinfra` replacement before attempting cutover again.

## Post-Cutover Verification

After each deletion (and again after the final commit), run:

```bash
# Validation path
easyinfra ci validate

# Deploy path (dry run first)
easyinfra apply --dry-run
easyinfra apply

# Backup path
easyinfra backup
ls -lh ./backups/   # confirm a new artefact appeared

# Cluster health
kubectl get nodes
kubectl get pods -A | grep -vE 'Running|Completed'

# CI is still green
gh run list --workflow easyinfra-validate.yml --limit 3
```

If all of the above succeed, the cutover is complete. Update the team in
`#infra` and close the migration ticket.
