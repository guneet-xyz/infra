# infra agent context

This repo is organized by machine. Each machine can contain one or more infra
stacks, such as k3s, Docker Compose, host services, or provisioning assets.

Start here:

- `machines/pax/AGENTS.md` for the current machine context
- `machines/pax/k3s/AGENTS.md` for the k3s stack entrypoint
- `machines/pax/k3s/docs/` for operations, chart conventions, networking, secrets, and backup details
- `machines/pax/k3s/kubolt.yaml` for deploy, dependency, and backup metadata
- `machines/pax/k3s/apps.yaml` for the app inventory (namespace, appName, port, exposure, dependencies, backups)

Validate the current k3s stack from `machines/pax/k3s`:

```sh
kubolt validate
```
