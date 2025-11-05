#!/usr/bin/env bash
set -euo pipefail

APPS_DIR="/mnt/APPS"
SCALE_NAMESPACE="ix-apps"

echo "=== Deploying TrueNAS SCALE Apps from $APPS_DIR ==="

# Check kubectl
if ! command -v kubectl &> /dev/null; then
  echo "⚠️ kubectl not found. Run this from the SCALE shell as root."
  exit 1
fi

# Loop over apps
for app_dir in "$APPS_DIR"/*; do
  [[ -d "$app_dir" ]] || continue
  APP_NAME=$(basename "$app_dir")
  VALUES_FILE="$app_dir/values.yaml"
  CHART_FILE="$app_dir/Chart.yaml"

  if [[ ! -f "$VALUES_FILE" || ! -f "$CHART_FILE" ]]; then
    echo "⚠️ Missing Chart.yaml or values.yaml in $app_dir - skipping"
    continue
  fi

  echo "Deploying app: $APP_NAME"

  # Temporary Helm chart directory
  TMP_HELM_DIR=$(mktemp -d)
  cp "$CHART_FILE" "$TMP_HELM_DIR/Chart.yaml"
  cp "$VALUES_FILE" "$TMP_HELM_DIR/values.yaml"

  # Generate Kubernetes manifests
  helm template "$APP_NAME" "$TMP_HELM_DIR" > "$TMP_HELM_DIR/deployment.yaml"

  # Apply manifests to ix-apps namespace
  kubectl apply -f "$TMP_HELM_DIR/deployment.yaml" -n "$SCALE_NAMESPACE"

  # Cleanup
  rm -rf "$TMP_HELM_DIR"

  echo "✅ $APP_NAME deployed successfully!"
done

echo "All apps deployed to TrueNAS SCALE Apps UI (namespace: $SCALE_NAMESPACE)"
