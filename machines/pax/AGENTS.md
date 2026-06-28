# Pax machine

This directory contains all infrastructure for the `pax` machine. Organize by
stack, not by cluster, so the machine can later host different infrastructure
bases side by side.

Current stacks:

- `k3s/` — single-node k3s stack managed with Helm, kubolt, and Obscuro.

When working on Kubernetes resources for `pax`, read `k3s/AGENTS.md` and run
validation from `machines/pax/k3s`.
