# headlamp

Kubernetes dashboard. Deployed as an umbrella chart using the official
[Headlamp Helm chart](https://github.com/kubernetes-sigs/headlamp).

> For install/upgrade/uninstall and backup commands, see [`../../docs/operations.md`](../../docs/operations.md) and [`../../docs/backup.md`](../../docs/backup.md).

## Get Login Token

Headlamp uses service account token authentication. After installing,
retrieve the token:

```sh
kubectl get secret headlamp-admin-token -n headlamp -o jsonpath='{.data.token}' | base64 -d
```

Use this token to log in to the Headlamp UI.
