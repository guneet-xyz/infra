#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backups"
REMOTE_HOST="pax"
REMOTE_TMP="/tmp/k3s-backups"

# ---------------------------------------------------------------------------
# App configuration
#
# Each app has one or more PVCs to back up. Deployments are discovered
# dynamically from the namespace so we scale down everything before tarring.
#
# The namespace is the same as the app name (convention from deploy.sh).
# ---------------------------------------------------------------------------
ALL_APPS="caddy walls litellm openwebui infisical registry dev-db"

# Returns the PVC names for a given app.
pvcs_for_app() {
  case "$1" in
    caddy)    echo "caddy-data" ;;
    walls)    echo "walls-postgres-data" ;;
    litellm)  echo "litellm-data litellm-postgres-data" ;;
    openwebui) echo "openwebui-data" ;;
    infisical) echo "infisical-postgres-data" ;;
    registry) echo "registry-data" ;;
    dev-db) echo "dev-db-postgres-data" ;;
    *)        return 1 ;;
  esac
}

is_valid_app() {
  pvcs_for_app "$1" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $0 <backup|restore> [app ...] [-- timestamp]

  backup  [app ...]              Back up PVCs (all apps if none specified)
  restore [app ...] [-- ts]      Restore PVCs from a backup

If no timestamp is given for restore, the latest backup is used.

Examples:
  $0 backup
  $0 backup walls
  $0 restore walls
  $0 restore litellm -- 2026-04-24_143000

Available apps: $ALL_APPS
EOF
  exit 1
}

log()  { echo "==> $*"; }
err()  { echo "ERROR: $*" >&2; exit 1; }

# Get the host path for a PVC via kubectl.
pvc_host_path() {
  local ns="$1" pvc="$2"
  local pv
  pv=$(kubectl get pvc "$pvc" -n "$ns" -o jsonpath='{.spec.volumeName}' 2>/dev/null) \
    || err "PVC '$pvc' not found in namespace '$ns'. Install the chart first."
  kubectl get pv "$pv" -o jsonpath='{.spec.local.path}' 2>/dev/null \
    || err "Could not resolve host path for PV '$pv'."
}

# Get all deployment names in a namespace.
deployments_in_namespace() {
  kubectl get deployments -n "$1" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null
}

# Scale all deployments in a namespace to a given replica count.
scale_deployments() {
  local ns="$1" replicas="$2"
  local deployments
  deployments=$(deployments_in_namespace "$ns")
  if [[ -z "$deployments" ]]; then
    return
  fi
  for dep in $deployments; do
    log "  Scaling $ns/$dep to $replicas"
    kubectl scale deployment "$dep" -n "$ns" --replicas="$replicas" --timeout=120s >/dev/null
  done
  if [[ "$replicas" -eq 0 ]]; then
    log "  Waiting for pods to terminate in $ns..."
    kubectl wait --for=delete pod --all -n "$ns" --timeout=120s 2>/dev/null || true
  fi
}

# Saved replica counts as lines of "namespace/deployment=count".
SAVED_REPLICAS=""

save_replicas() {
  local ns="$1"
  local deployments
  deployments=$(deployments_in_namespace "$ns")
  for dep in $deployments; do
    local count
    count=$(kubectl get deployment "$dep" -n "$ns" -o jsonpath='{.spec.replicas}')
    SAVED_REPLICAS="${SAVED_REPLICAS}${ns}/${dep}=${count}"$'\n'
  done
}

restore_replicas() {
  local ns="$1"
  echo "$SAVED_REPLICAS" | while IFS='=' read -r key count; do
    if [[ "$key" == "$ns/"* && -n "$count" ]]; then
      local dep="${key#$ns/}"
      log "  Scaling $ns/$dep back to $count"
      kubectl scale deployment "$dep" -n "$ns" --replicas="$count" --timeout=120s >/dev/null
    fi
  done
}

# ---------------------------------------------------------------------------
# Backup
# ---------------------------------------------------------------------------
do_backup() {
  local timestamp
  timestamp=$(date +%Y-%m-%d_%H%M%S)
  local local_dir="$BACKUP_DIR/$timestamp"

  mkdir -p "$local_dir"
  log "Backup directory: $local_dir"

  ssh "$REMOTE_HOST" "mkdir -p $REMOTE_TMP/$timestamp"

  for app in "$@"; do
    local ns="$app"
    local pvcs
    pvcs=$(pvcs_for_app "$app")

    log "Backing up $app..."
    save_replicas "$ns"
    scale_deployments "$ns" 0

    for pvc in $pvcs; do
      local host_path
      host_path=$(pvc_host_path "$ns" "$pvc")
      log "  Tarring $pvc ($host_path)..."
      ssh "$REMOTE_HOST" "tar czf $REMOTE_TMP/$timestamp/$pvc.tar.gz -C '$host_path' ."
    done

    restore_replicas "$ns"
  done

  log "Copying backups to $local_dir..."
  scp -r "$REMOTE_HOST:$REMOTE_TMP/$timestamp/"* "$local_dir/"

  ssh "$REMOTE_HOST" "rm -rf $REMOTE_TMP/$timestamp"

  log "Backup complete: $local_dir"
  ls -lh "$local_dir"
}

# ---------------------------------------------------------------------------
# Restore
# ---------------------------------------------------------------------------
do_restore() {
  local local_dir

  if [[ -n "$TIMESTAMP" ]]; then
    local_dir="$BACKUP_DIR/$TIMESTAMP"
  else
    local latest
    latest=$(ls -1t "$BACKUP_DIR" 2>/dev/null | head -1)
    [[ -n "$latest" ]] || err "No backups found in $BACKUP_DIR"
    local_dir="$BACKUP_DIR/$latest"
    TIMESTAMP="$latest"
  fi

  [[ -d "$local_dir" ]] || err "Backup directory not found: $local_dir"
  log "Restoring from: $local_dir"

  # Verify all expected files exist before starting
  for app in "$@"; do
    local pvcs
    pvcs=$(pvcs_for_app "$app")
    for pvc in $pvcs; do
      [[ -f "$local_dir/$pvc.tar.gz" ]] \
        || err "Missing backup file: $local_dir/$pvc.tar.gz"
    done
  done

  ssh "$REMOTE_HOST" "mkdir -p $REMOTE_TMP/$TIMESTAMP"
  log "Copying backups to remote..."
  scp -r "$local_dir/"* "$REMOTE_HOST:$REMOTE_TMP/$TIMESTAMP/"

  for app in "$@"; do
    local ns="$app"
    local pvcs
    pvcs=$(pvcs_for_app "$app")

    log "Restoring $app..."
    save_replicas "$ns"
    scale_deployments "$ns" 0

    for pvc in $pvcs; do
      local host_path
      host_path=$(pvc_host_path "$ns" "$pvc")
      log "  Extracting $pvc into $host_path..."
      ssh "$REMOTE_HOST" "rm -rf '$host_path'/* && tar xzf $REMOTE_TMP/$TIMESTAMP/$pvc.tar.gz -C '$host_path'"
    done

    restore_replicas "$ns"
  done

  ssh "$REMOTE_HOST" "rm -rf $REMOTE_TMP/$TIMESTAMP"

  log "Restore complete."
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if [[ $# -lt 1 ]]; then
  usage
fi

ACTION="$1"
shift

# Parse apps and timestamp (separated by --)
APPS=""
TIMESTAMP=""
parsing_apps=true
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "--" ]]; then
    parsing_apps=false
    shift
    continue
  fi
  if $parsing_apps; then
    is_valid_app "$1" || err "Unknown app: $1. Available: $ALL_APPS"
    APPS="$APPS $1"
  else
    TIMESTAMP="$1"
  fi
  shift
done

# Default to all apps if none specified
if [[ -z "$APPS" ]]; then
  APPS="$ALL_APPS"
fi

case "$ACTION" in
  backup)
    do_backup $APPS
    ;;
  restore)
    do_restore $APPS
    ;;
  *)
    err "Unknown action: $ACTION"
    ;;
esac
