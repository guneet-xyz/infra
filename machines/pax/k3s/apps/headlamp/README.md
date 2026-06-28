# headlamp

Kubernetes dashboard. Deployed as an umbrella chart using the official
[Headlamp Helm chart](https://github.com/kubernetes-sigs/headlamp).

## Install

From the `machines/pax/k3s/` directory:

```sh
kubolt install headlamp
```

## Upgrade

```sh
kubolt install headlamp
```

## Uninstall

```sh
kubolt uninstall headlamp
```

## Get Login Token

Headlamp uses service account token authentication. After installing,
retrieve the token:

```sh
kubectl get secret headlamp-admin-token -n headlamp -o jsonpath='{.data.token}' | base64 -d
```

Use this token to log in to the Headlamp UI.
