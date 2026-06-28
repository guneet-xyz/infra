# Backup

## Backups

Use `kubolt backup` to back up PVC data. Backup targets live in
`kubolt.yaml`. During backup, kubolt can scale deployments in the app's
namespace to zero and restore their original replica counts afterward when
`scaleDeployments: true` is set.

```sh
kubolt backup --dir ./backups walls
```

### Adding a New App to Backups

Edit `kubolt.yaml` and add backup targets under the app's `backup.targets`
list.

### Restore After Data Loss

If PVCs were deleted (e.g., after `kubolt uninstall`), reinstall the chart
first with `kubolt install <chart>` to recreate the PVCs, then restore the
data from the backup archive using the matching PVC path.
