#!/usr/bin/env bash
set -euo pipefail

# TrueNAS Scale manifest generator (native app manifests)
# - Hardcoded pools: /mnt/APPS and /mnt/STORAGE
# - Creates directories and generates Chart.yaml + values.yaml per app
# - Does NOT call kubectl (safe for Web UI Shell)
# - Uses apps UID/GID 568:568
# - qBittorrent is preconfigured as requested

APPS_POOL="APPS"
STORAGE_POOL="STORAGE"

BASE_APPS_DIR="/mnt/${APPS_POOL}"
BASE_MEDIA_DIR="/mnt/${STORAGE_POOL}"

PUID="568"
PGID="568"
TZ="Europe/Amsterdam"

APPLIST=(jellyfin sonarr radarr tdarr prowlarr qbittorrent)

echo "=== TrueNAS SCALE manifest generator ==="
echo "APPS pool: $APPS_POOL -> $BASE_APPS_DIR"
echo "STORAGE pool: $STORAGE_POOL -> $BASE_MEDIA_DIR"
echo

# Ask about NVIDIA GPU support (optional)
GPU_TYPE="none"
read -p "Do you want to add NVIDIA GPU reservations to Jellyfin/Tdarr manifests? (yes/no) [no]: " gpu_reply
gpu_reply="${gpu_reply:-no}"
if [[ "${gpu_reply,,}" =~ ^(y|yes)$ ]]; then
  GPU_TYPE="nvidia"
  read -p "Enter NVIDIA GPU model identifier for values.yaml (example: 'all' or 'RTX3060'): " NVIDIA_MODEL
  NVIDIA_MODEL="${NVIDIA_MODEL:-all}"
fi

# Ensure base mount points exist
mkdir -p "$BASE_APPS_DIR"
mkdir -p "$BASE_MEDIA_DIR"

# Create media subdirs
MEDIA_SUBDIRS=("movies" "tv" "downloads" "Incomplete" "Completed" "Completed Torrents")
for d in "${MEDIA_SUBDIRS[@]}"; do
  mp="$BASE_MEDIA_DIR/$d"
  if [ ! -d "$mp" ]; then
    mkdir -p "$mp"
    chown "${PUID}:${PGID}" "$mp" || chown apps:apps "$mp" 2>/dev/null || true
    chmod 770 "$mp"
    echo "Created media dir: $mp"
  fi
done

# Create tdarr subdirs under APPS pool (configs live directly under APPS)
TDARR_SUBDIRS=("server" "logs" "transcode_cache")
for d in "${TDARR_SUBDIRS[@]}"; do
  mp="$BASE_APPS_DIR/tdarr/$d"
  if [ ! -d "$mp" ]; then
    mkdir -p "$mp"
    chown "${PUID}:${PGID}" "$mp" || chown apps:apps "$mp" 2>/dev/null || true
    chmod 770 "$mp"
    echo "Created tdarr config dir: $mp"
  fi
done

# Helper: write Chart.yaml
write_chart_yaml() {
  local app="$1"
  local chart_file="$2"
  cat > "$chart_file" <<EOF
apiVersion: v2
name: ${app}
description: "${app} - generated TrueNAS SCALE app package (auto)"
type: application
version: 0.1.0
appVersion: "1.0"
EOF
}

# Helper: write values.yaml (simple container spec that TrueNAS UI accepts)
# We craft values that map to a container image, ports, volumes and env.
write_values_yaml() {
  local app="$1"
  local values_file="$2"
  local image="$3"
  local ports_yaml="$4"       # preformatted YAML block (indented)
  local volumes_yaml="$5"     # preformatted YAML block (indented)
  local env_yaml="$6"         # preformatted YAML block (indented)
  local gpu_block="$7"        # optional GPU block (indented)

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

# Helper: format ports for values.yaml
format_ports_block() {
  local -n ports_ref=$1
  local out="  ports:"
  for p in "${ports_ref[@]}"; do
    # p expected in format "host:container" or "port:port"
    host_port="${p%%:*}"
    container_port="${p##*:}"
    out+="\n    - name: port-${container_port}\n      port: ${container_port}\n      targetPort: ${container_port}\n      nodePort: ${host_port}"
  done
  echo -e "$out"
}

# Helper: format volumes for values.yaml
format_volumes_block() {
  local -n vols_ref=$1
  local out="  enabled: true\n  mounts:"
  for v in "${vols_ref[@]}"; do
    # v format: "/host/path:/container/path"
    host="${v%%:*}"
    container="${v#*:}"
    out+="\n    - name: $(basename "$container")\n      mountPath: ${container}\n      hostPath: ${host}"
  done
  echo -e "$out"
}

# Helper: format env block
format_env_block() {
  local -n env_ref=$1
  local out="  - name: DUMMY\n    value: \"\"\n"
  # We'll convert to a simple mapping expected by TrueNAS values.yaml env section:
  # produce entries like:   - name: PUID\n      value: "568"
  out=""
  for e in "${env_ref[@]}"; do
    key="${e%%=*}"
    val="${e#*=}"
    out+="  - name: ${key}\n    value: \"${val}\"\n"
  done
  echo -e "$out"
}

# Create per-app folders and files
for app in "${APPLIST[@]}"; do
  APP_DIR="$BASE_APPS_DIR/$app"
  mkdir -p "$APP_DIR"
  chown "${PUID}:${PGID}" "$APP_DIR" || chown apps:apps "$APP_DIR" 2>/dev/null || true
  chmod 770 "$APP_DIR"

  CHART_FILE="$APP_DIR/Chart.yaml"
  VALUES_FILE="$APP_DIR/values.yaml"

  case "$app" in
    jellyfin)
      IMAGE="lscr.io/linuxserver/jellyfin:latest"
      PORTS=("8096:8096")
      VOLS=("/mnt/${APPS_POOL}/jellyfin:/config" "/mnt/${STORAGE_POOL}:/media")
      ENVS=("PUID=${PUID}" "PGID=${PGID}" "TZ=${TZ}")
      ;;
    sonarr)
      IMAGE="linuxserver/sonarr:latest"
      PORTS=("8989:8989")
      VOLS=("/mnt/${APPS_POOL}/sonarr:/config" "/mnt/${STORAGE_POOL}:/media")
      ENVS=("PUID=${PUID}" "PGID=${PGID}" "TZ=${TZ}" "SONARR_ROOTFOLDER=/media/tv")
      ;;
    radarr)
      IMAGE="linuxserver/radarr:latest"
      PORTS=("7878:7878")
      VOLS=("/mnt/${APPS_POOL}/radarr:/config" "/mnt/${STORAGE_POOL}:/media")
      ENVS=("PUID=${PUID}" "PGID=${PGID}" "TZ=${TZ}" "RADARR_ROOTFOLDER=/media/movies")
      ;;
    tdarr)
      IMAGE="haveagitgat/tdarr:latest"
      PORTS=("8265:8265" "8266:8266")
      VOLS=("/mnt/${APPS_POOL}/tdarr:/app/config" "/mnt/${STORAGE_POOL}:/media")
      ENVS=("PUID=${PUID}" "PGID=${PGID}" "TZ=${TZ}" "TDARR_CACHE=/app/config/transcode_cache")
      ;;
    prowlarr)
      IMAGE="linuxserver/prowlarr:latest"
      PORTS=("9696:9696")
      VOLS=("/mnt/${APPS_POOL}/prowlarr:/config" "/mnt/${STORAGE_POOL}:/media")
      ENVS=("PUID=${PUID}" "PGID=${PGID}" "TZ=${TZ}")
      ;;
    qbittorrent)
      IMAGE="ghcr.io/hotio/qbittorrent"
      PORTS=("10080:10080")
      VOLS=("/mnt/${APPS_POOL}/qbittorrent:/config" "/mnt/${STORAGE_POOL}:/media")
      ENVS=("PUID=${PUID}" "PGID=${PGID}" "UMASK=002" "TZ=${TZ}" \
"INCOMPLETE_PATH=/media/Incomplete" \
"COMPLETED_PATH=/media/Completed" \
"COMPLETED_TORRENTS_PATH=/media/Completed Torrents" \
"GLOBAL_MAX_CONNECTIONS=500" \
"MAX_CONNECTIONS_PER_TORRENT=100" \
"GLOBAL_MAX_UPLOADS=20" \
"MAX_UPLOADS_PER_TORRENT=4" \
"MAX_ACTIVE_DOWNLOADS=3" \
"MAX_ACTIVE_UPLOADS=100" \
"MAX_ACTIVE_TORRENTS=500" \
"IGNORE_SLOW_TORRENTS=true" \
"TOTAL_SEED_TIME=50000" \
"DHT=false" \
"PEER_EXCHANGE=false" \
"LOCAL_PEER_DISCOVERY=false" \
"RSS_REFRESH_INTERVAL=30" \
"RSS_MAX_ARTICLES=500" \
"RSS_AUTO_DOWNLOAD=true" \
"TORRENT_MODE=automatic" \
"DEFAULT_SAVE_PATH=/media/Completed")
      ;;
    *)
      echo "Unknown app: $app - skipping"
      continue
      ;;
  esac

  # Write Chart.yaml & values.yaml
  write_chart_yaml "$app" "$CHART_FILE"

  # Prepare YAML blocks for values.yaml
  ports_block="$(format_ports_block ports_array)"
  # Because format_ports_block expects a named array ref, create it dynamically:
  eval "ports_array=(\"\${PORTS[@]}\")"
  ports_block="$(format_ports_block ports_array)"

  eval "vols_array=(\"\${VOLS[@]}\")"
  volumes_block="$(format_volumes_block vols_array)"

  eval "env_array=(\"\${ENVS[@]}\")"
  env_block="$(format_env_block env_array)"

  gpu_block=""
  if [[ "$app" =~ ^(jellyfin|tdarr)$ ]] && [[ "$GPU_TYPE" == "nvidia" ]]; then
    gpu_block="resources:\n  reservations:\n    devices:\n      - driver: nvidia\n        count: all\n        capabilities: [gpu]\nnvidia:\n  visible_devices: \"${NVIDIA_MODEL}\""
  fi

  # Write values.yaml
  write_values_yaml "$app" "$VALUES_FILE" "$IMAGE" "$ports_block" "$volumes_block" "$env_block" "$gpu_block"

  # Fix permissions
  chown "${PUID}:${PGID}" "$CHART_FILE" "$VALUES_FILE" || chown apps:apps "$CHART_FILE" "$VALUES_FILE" 2>/dev/null || true
  chmod 660 "$CHART_FILE" "$VALUES_FILE"

  echo "Generated manifest package for $app in $APP_DIR"
done

echo
echo "=== Generation complete ==="
echo "You will find app packages at:"
for app in "${APPLIST[@]}"; do
  echo " - $BASE_APPS_DIR/$app"
done

cat <<'EOF'

How to install these packages in the TrueNAS SCALE UI (no kubectl required):

1) Open TrueNAS SCALE web UI -> Apps -> Manage Apps (or Discover -> Install via YAML)
2) For each app folder (e.g. /mnt/APPS/jellyfin) open the values.yaml file and copy its contents.
   Use "Install via YAML" (or Upload YAML) and paste the generated values.yaml / Chart.yaml as needed.
   If the UI asks for a full app manifest, paste the values.yaml combined with Chart.yaml metadata.
   (Alternatively, drag & drop these files in the Apps "Upload YAML" dialog if your SCALE version supports it.)
3) After install, the app will appear in Apps list. Configure any app-specific UI options when needed.

Notes:
 - This script intentionally does NOT call kubectl; it only creates the native package files.
 - Files are owned by UID:GID ${PUID}:${PGID} and have restrictive permissions (770/660).
 - Media folders created: ${MEDIA_SUBDIRS[*]} under $BASE_MEDIA_DIR
 - Tdarr subfolders: ${TDARR_SUBDIRS[*]} under $BASE_APPS_DIR/tdarr

EOF
