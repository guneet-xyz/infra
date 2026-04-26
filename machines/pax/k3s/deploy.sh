#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="$SCRIPT_DIR/apps"
SHARED_VALUES="$SCRIPT_DIR/values-shared.yaml"

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
      --atomic --wait \
      --post-renderer obscuro --post-renderer-args inject
    ;;
  upgrade)
    echo "Upgrading $CHART in namespace $NAMESPACE..."
    helm upgrade "$CHART" "$CHART_DIR" \
      -n "$NAMESPACE" \
      -f "$SHARED_VALUES" \
      -f "$CHART_DIR/values.yaml" \
      --atomic --wait \
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
