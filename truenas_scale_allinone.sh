#!/usr/bin/env bash
set -euo pipefail

APPS_POOL="APPS"
STORAGE_POOL="STORAGE"

BASE_APPS_DIR="/mnt/${APPS_POOL}"
BASE_MEDIA_DIR="/mnt/${STORAGE_POOL}"

PUID="568"
PGID="568"

APPLIST=(jellyfin sonarr radarr tdarr prowlarr qbittorrent)

echo "=== TrueNAS SCALE All-in-One App Setup ==="
echo "APPS pool: $APPS_POOL -> $BASE_APPS_DIR"
echo "STORAGE pool: $STORAGE_POOL -> $BASE_MEDIA_DIR"
echo

# NVIDIA GPU support
GPU_TYPE="none"
read -p "Do you want to add NVIDIA GPU support to Jellyfin/Tdarr? (yes/no) [no]: " gpu_reply
gpu_reply="${gpu_reply:-no}"
if [[ "${gpu_reply,,}" =~ ^(y|yes)$ ]]; then
  GPU_TYPE="nvidia"
  read -p "Enter NVIDIA GPU model identifier (e.g., 'all' or 'RTX3060'): " NVIDIA_MODEL
  NVIDIA_MODEL="${NVIDIA_MODEL:-all}"
fi

# -------------------------------
# Create base directories
# -------------------------------
mkdir -p "$BASE_APPS_DIR"
mkdir -p "$BASE_MEDIA_DIR"

MEDIA_SUBDIRS=("Downloads/Incomplete" "Downloads/Completed" "Downloads/Completed Torrents" "Media")
for d in "${MEDIA_SUBDIRS[@]}"; do
  mp="$BASE_MEDIA_DIR/$d"
  mkdir -p "$mp"
  chown "${PUID}:${PGID}" "$mp" || true
  chmod 770 "$mp"
done

TDARR_SUBDIRS=("server" "logs" "transcode_cache")
for d in "${TDARR_SUBDIRS[@]}"; do
  mp="$BASE_APPS_DIR/tdarr/$d"
  mkdir -p "$mp"
  chown "${PUID}:${PGID}" "$mp" || true
  chmod 770 "$mp"
done

# -------------------------------
# Helpers
# -------------------------------
write_chart_yaml() {
  local dataset="$1"
  local chart_file="$2"
  cat > "$chart_file" <<EOF
apiVersion: v2
name: ${dataset}
description: "${dataset} - generated TrueNAS SCALE app package (auto)"
type: application
version: 0.1.0
appVersion: "1.0"
EOF
}

write_values_yaml() {
  local app="$1"
  local values_file="$2"
  local image="$3"
  local ports_yaml="$4"
  local volumes_yaml="$5"
  local env_yaml="$6"
  local gpu_block="$7"

  cat > "$values_file" <<EOF
replicaCount: 1
image:
  repository: ${image}
  pullPolicy: IfNotPresent
service:
${ports_yaml}
persistence:
${volumes_yaml}
env:
${env_yaml}
${gpu_block}
EOF
}

format_ports_block() {
  local -n ports_ref=$1
  local out="  ports:"
  for p in "${ports_ref[@]}"; do
    host_port="${p%%:*}"
    container_port="${p##*:}"
    out+="
    - name: port-${container_port}
      port: ${container_port}
      targetPort: ${container_port}
      nodePort: ${host_port}"
  done
  echo "$out"
}

format_volumes_block() {
  local -n vols_ref=$1
  local out="  enabled: true
  mounts:"
  for v in "${vols_ref[@]}"; do
    host="${v%%:*}"
    container="${v#*:}"
    out+="
    - name: $(basename "$container")
      mountPath: ${container}
      hostPath: ${host}"
  done
  echo "$out"
}

format_env_block() {
  local -n env_ref=$1
  local out=""
  for e in "${env_ref[@]}"; do
    key="${e%%=*}"
    val="${e#*=}"
    out+="  - name: ${key}
    value: \"${val}\"
"
  done
  echo "$out"
}

# -------------------------------
# Generate per-app manifests
# -------------------------------
for app in "${APPLIST[@]}"; do
  APP_DIR="$BASE_APPS_DIR/$app"
  mkdir -p "$APP_DIR"
  chown "${PUID}:${PGID}" "$APP_DIR" || true
  chmod 770 "$APP_DIR"

  CHART_FILE="$APP_DIR/Chart.yaml"
  VALUES_FILE="$APP_DIR/values.yaml"

  # Overwrite files if they exist
  [[ -f "$CHART_FILE" ]] && echo "⚠️ $CHART_FILE exists - overwriting"
  [[ -f "$VALUES_FILE" ]] && echo "⚠️ $VALUES_FILE exists - overwriting"

  case "$app" in
    jellyfin)
      IMAGE="lscr.io/linuxserver/jellyfin:latest"
      PORTS=("8096:8096")
      VOLS=("$BASE_APPS_DIR/jellyfin:/config" "$BASE_MEDIA_DIR:/media")
      ENVS=("PUID=${PUID}" "PGID=${PGID}")
      ;;
    sonarr)
      IMAGE="linuxserver/sonarr:latest"
      PORTS=("8989:8989")
      VOLS=("$BASE_APPS_DIR/sonarr:/config" "$BASE_MEDIA_DIR:/media")
      ENVS=("PUID=${PUID}" "PGID=${PGID}" "SONARR_ROOTFOLDER=/media/tv")
      ;;
    radarr)
      IMAGE="linuxserver/radarr:latest"
      PORTS=("7878:7878")
      VOLS=("$BASE_APPS_DIR/radarr:/config" "$BASE_MEDIA_DIR:/media")
      ENVS=("PUID=${PUID}" "PGID=${PGID}" "RADARR_ROOTFOLDER=/media/movies")
      ;;
    tdarr)
      IMAGE="haveagitgat/tdarr:latest"
      PORTS=("8265:8265" "8266:8266")
      VOLS=("$BASE_APPS_DIR/tdarr:/app/config" "$BASE_MEDIA_DIR:/media")
      ENVS=("PUID=${PUID}" "PGID=${PGID}" "TDARR_CACHE=/app/config/transcode_cache")
      ;;
    prowlarr)
      IMAGE="linuxserver/prowlarr:latest"
      PORTS=("9696:9696")
      VOLS=("$BASE_APPS_DIR/prowlarr:/config" "$BASE_MEDIA_DIR:/media")
      ENVS=("PUID=${PUID}" "PGID=${PGID}")
      ;;
    qbittorrent)
      IMAGE="lscr.io/linuxserver/qbittorrent:latest"
      PORTS=("10080:10080")
      VOLS=("$BASE_APPS_DIR/qbittorrent:/config" "$BASE_MEDIA_DIR:/media")
      ENVS=(
        "PUID=${PUID}" "PGID=${PGID}"
        "INCOMPLETE_PATH=/media/Downloads/Incomplete"
        "COMPLETED_PATH=/media/Downloads/Completed"
        "COMPLETED_TORRENTS_PATH=/media/Downloads/Completed Torrents"
        "GLOBAL_MAX_CONNECTIONS=500"
        "MAX_CONNECTIONS_PER_TORRENT=100"
        "GLOBAL_MAX_UPLOADS=20"
        "MAX_UPLOADS_PER_TORRENT=4"
        "MAX_ACTIVE_DOWNLOADS=3"
        "MAX_ACTIVE_UPLOADS=100"
        "MAX_ACTIVE_TORRENTS=500"
        "IGNORE_SLOW_TORRENTS=true"
        "TOTAL_SEED_TIME=50000"
        "DHT=false" "PEER_EXCHANGE=false" "LOCAL_PEER_DISCOVERY=false"
        "RSS_REFRESH_INTERVAL=30"
        "RSS_MAX_ARTICLES=500"
        "RSS_AUTO_DOWNLOAD=true"
        "TORRENT_MODE=automatic"
        "DEFAULT_SAVE_PATH=/media/Downloads/Completed"
      )
      ;;
    *)
      echo "Unknown app: $app - skipping"
      continue
      ;;
  esac

  # Write YAMLs
  write_chart_yaml "$app" "$CHART_FILE"
  ports_block="$(format_ports_block PORTS)"
  volumes_block="$(format_volumes_block VOLS)"
  env_block="$(format_env_block ENVS)"

  gpu_block=""
  if [[ "$app" =~ ^(jellyfin|tdarr)$ ]] && [[ "$GPU_TYPE" == "nvidia" ]]; then
    gpu_block="resources:
  reservations:
    devices:
      - driver: nvidia
        count: ${NVIDIA_MODEL}
        capabilities: [gpu]"
  fi

  write_values_yaml "$app" "$VALUES_FILE" "$IMAGE" "$ports_block" "$volumes_block" "$env_block" "$gpu_block"

  echo "=== Generated App Compose YAML for $app ==="
  cat "$VALUES_FILE"
  echo
done

# -------------------------------
# Deploy apps to SCALE
# -------------------------------
SCALE_NAMESPACE="ix-apps"

if ! command -v kubectl &> /dev/null; then
  echo "⚠️ kubectl not found. Deploy manually from SCALE shell"
  exit 0
fi

for app_dir in "$BASE_APPS_DIR"/*; do
  [[ -d "$app_dir" ]] || continue
  APP_NAME=$(basename "$app_dir")
  VALUES_FILE="$app_dir/values.yaml"
  CHART_FILE="$app_dir/Chart.yaml"

  [[ -f "$VALUES_FILE" && -f "$CHART_FILE" ]] || continue

  echo "Deploying $APP_NAME to TrueNAS SCALE..."

  TMP_HELM_DIR=$(mktemp -d)
  cp "$CHART_FILE" "$TMP_HELM_DIR/Chart.yaml"
  cp "$VALUES_FILE" "$TMP_HELM_DIR/values.yaml"

  helm template "$APP_NAME" "$TMP_HELM_DIR" > "$TMP_HELM_DIR/deployment.yaml"
  kubectl apply -f "$TMP_HELM_DIR/deployment.yaml" -n "$SCALE_NAMESPACE"
  rm -rf "$TMP_HELM_DIR"

  echo "✅ $APP_NAME
