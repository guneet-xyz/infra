#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="$SCRIPT_DIR/apps"
SHARED_VALUES="$SCRIPT_DIR/values-shared.yaml"

errors=0

if [[ ! -f "$SHARED_VALUES" ]]; then
  echo "WARN: values-shared.yaml not found at $SHARED_VALUES"
fi

for chart_dir in "$APPS_DIR"/*/; do
  chart_name="$(basename "$chart_dir")"

  if [[ ! -f "$chart_dir/Chart.yaml" ]]; then
    echo "SKIP: $chart_name — no Chart.yaml found"
    continue
  fi

  echo "Validating $chart_name..."

  # Build helm template args
  args=("$chart_dir")
  if [[ -f "$SHARED_VALUES" ]]; then
    args+=(-f "$SHARED_VALUES")
  fi
  if [[ -f "$chart_dir/values.yaml" ]]; then
    args+=(-f "$chart_dir/values.yaml")
  fi

  # Render templates
  if ! output=$(helm template "${args[@]}" 2>&1); then
    echo "FAIL: $chart_name"
    echo "$output"
    errors=$((errors + 1))
    continue
  fi

  echo "OK:   $chart_name"
done

echo ""
if [[ $errors -gt 0 ]]; then
  echo "$errors chart(s) failed validation."
  exit 1
else
  echo "All charts passed validation."
fi
