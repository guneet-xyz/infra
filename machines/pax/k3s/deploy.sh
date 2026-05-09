#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="$SCRIPT_DIR/apps"
SHARED_VALUES="$SCRIPT_DIR/values-shared.yaml"
PLUGINS_DIR="$SCRIPT_DIR/plugins"

# Helm v4 requires post-renderers to be registered as plugins (HIP);
# install local plugin manifests on first run.
ensure_helm_plugin() {
  local name="$1"
  local src="$PLUGINS_DIR/$name"

  if [[ ! -f "$src/plugin.yaml" ]]; then
    echo "Error: missing plugin manifest at $src/plugin.yaml"
    exit 1
  fi

  if ! helm plugin list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$name"; then
    echo "Installing helm plugin: $name"
    helm plugin install "$src"
  fi
}

require_command() {
  local name="$1"
  local hint="$2"
  if ! command -v "$name" >/dev/null 2>&1; then
    cat >&2 <<EOF
Error: '$name' not found on PATH.

$hint

Current PATH: $PATH
EOF
    exit 1
  fi
}

ensure_obscuro_ready() {
  require_command obscuro \
"The Helm post-renderer plugin shells out to 'obscuro inject' to decrypt
secret placeholders at deploy time. Install it and ensure it is on PATH."

  local keychain_status
  keychain_status="$(obscuro auth status 2>/dev/null || true)"
  if [[ "$keychain_status" == *"no password"* ]] \
     && [[ -z "${OBSCURO_PASSWORD:-}" ]]; then
    cat >&2 <<EOF
Error: obscuro has no non-interactive password source.

Helm runs the post-renderer as a subprocess with no TTY, so 'obscuro inject'
cannot prompt for the master password. Provide one of:

  1. Store it in the OS keychain (recommended, one-time):
       obscuro auth store

  2. Export it for this shell:
       export OBSCURO_PASSWORD='...'
EOF
    exit 1
  fi
}

require_command helm "Install Helm v4+: https://helm.sh/docs/intro/install/"
require_command kubectl "Install kubectl: https://kubernetes.io/docs/tasks/tools/"
ensure_obscuro_ready
ensure_helm_plugin obscuro

usage() {
  echo "Usage: $0 <chart> [install|upgrade|uninstall]"
  echo ""
  echo "Examples:"
  echo "  $0 caddy install"
  echo "  $0 walls upgrade"
  echo "  $0 walls uninstall"
  echo ""
  echo "Available charts:"
  for dir in "$APPS_DIR"/*/; do
    if [[ -f "$dir/Chart.yaml" ]]; then
      echo "  $(basename "$dir")"
    fi
  done
  exit 1
}

if [[ $# -lt 2 ]]; then
  usage
fi

CHART="$1"
ACTION="$2"
CHART_DIR="$APPS_DIR/$CHART"

if [[ ! -f "$CHART_DIR/Chart.yaml" ]]; then
  echo "Error: chart '$CHART' not found at $CHART_DIR"
  exit 1
fi

# Namespace matches the chart directory name by convention
NAMESPACE="$CHART"

case "$ACTION" in
  install)
    echo "Installing $CHART into namespace $NAMESPACE..."
    helm install "$CHART" "$CHART_DIR" \
      -n "$NAMESPACE" --create-namespace \
      -f "$SHARED_VALUES" \
      -f "$CHART_DIR/values.yaml" \
      --rollback-on-failure --wait \
      --post-renderer obscuro --post-renderer-args inject
    ;;
  upgrade)
    echo "Upgrading $CHART in namespace $NAMESPACE..."
    helm upgrade "$CHART" "$CHART_DIR" \
      -n "$NAMESPACE" \
      -f "$SHARED_VALUES" \
      -f "$CHART_DIR/values.yaml" \
      --rollback-on-failure --wait \
      --post-renderer obscuro --post-renderer-args inject
    ;;
  uninstall)
    echo "Uninstalling $CHART from namespace $NAMESPACE..."
    helm uninstall "$CHART" -n "$NAMESPACE"
    ;;
  *)
    echo "Error: unknown action '$ACTION'. Must be install, upgrade, or uninstall."
    exit 1
    ;;
esac
