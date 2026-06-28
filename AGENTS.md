# infra agent context

This repo is organized by machine. Each machine can contain one or more infra
stacks, such as k3s, Docker Compose, host services, or provisioning assets.

Start here:

- `machines/pax/AGENTS.md` for the current machine context
- `machines/pax/k3s/AGENTS.md` for the current k3s stack context
- `machines/pax/k3s/kubolt.yaml` for deploy, dependency, and backup metadata

Validate the current k3s stack from `machines/pax/k3s`:

```sh
kubolt validate
```
