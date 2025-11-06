#!/usr/bin/env bash
set -euo pipefail

# truenas_scale_allinone.sh
# All-in-one generator + deployer for TrueNAS SCALE (modified to use k3s kubectl
# and to overwrite/clean existing resources). Designed for APPS/STORAGE datastores.

APPS_POOL="APPS"
STORAGE_POOL="STORAGE"

BASE_APPS_DIR="/mnt/${APPS_POOL}"
BASE_MEDIA_DIR="/mnt/${STORAGE_POOL}"

PUID="568"
PGID="568"

APPLIST=(jellyfin sonarr radarr tdarr prowlarr qbittorrent jellyseerr bazarr dozzle recyclarr flaresolverr watchtower)

# Namespace used by TrueNAS SCALE apps
SCALE_NAMESPACE="ix-apps"

# Tools
K3S_KUBECTL="k3s kubectl"
HELM_BIN="helm"

echo "=== TrueNAS SCALE All-in-One Installer (updated) ==="
echo "APPS pool: $BASE_APPS_DIR"
echo "STORAGE pool: $BASE_MEDIA_DIR"
echo

# Prompt for NVIDIA GPU support
GPU_TYPE="none"
read -p "Add NVIDIA GPU support for Jellyfin/Tdarr? (yes/no) [no]: " gpu_reply
gpu_reply="${gpu_reply:-no}"
if [[ "${gpu_reply,,}" =~ ^(y|yes)$ ]]; then
  GPU_TYPE="nvidia"
  read -p "Enter NVIDIA visible devices value (e.g. 'all' or 'GPU-UUID' or '0'): " NVIDIA_VISIBLE
  NVIDIA_VISIBLE="${NVIDIA_VISIBLE:-all}"
fi

# Ensure target mount points exist
mkdir -p "$BASE_APPS_DIR"
mkdir -p "$BASE_MEDIA_DIR"

# Create media subdirectories (Option A)
MEDIA_SUBDIRS=("Downloads/Incomplete" "Downloads/Completed" "Downloads/Completed Torrents" "Media")
for d in "${MEDIA_SUBDIRS[@]}"; do
  mp="$BASE_MEDIA_DIR/$d"
  if [ -d "$mp" ]; then
    echo "Exists: $mp"
  else
    mkdir -p "$mp"
    echo "Created: $mp"
  fi
  chown "${PUID}:${PGID}" "$mp" || true
  chmod 770 "$mp" || true
done

# Create Tdarr config subdirs under APPS
TDARR_SUBDIRS=("server" "logs" "transcode_cache")
for d in "${TDARR_SUBDIRS[@]}"; do
  mp="$BASE_APPS_DIR/tdarr/$d"
  if [ -d "$mp" ]; then
    echo "Exists: $mp"
  else
    mkdir -p "$mp"
    echo "Created: $mp"
  fi
  chown "${PUID}:${PGID}" "$mp" || true
  chmod 770 "$mp" || true
done

# Ensure APPS base dirs exist
for app in "${APPLIST[@]}"; do
  appdir="$BASE_APPS_DIR/$app"
  if [ ! -d "$appdir" ]; then
    mkdir -p "$appdir"
    echo "Created app dir: $appdir"
  fi
  chown "${PUID}:${PGID}" "$appdir" || true
  chmod 770 "$appdir" || true
done

# helper: write Chart.yaml
write_chart_yaml() {
  local app="$1"
  local chartfile="$2"
  cat > "$chartfile" <<EOF
apiVersion: v2
name: ${app}
description: ${app} - generated TrueNAS SCALE app package
type: application
version: 0.1.0
appVersion: "1.0"
EOF
}

# helper: write values.yaml
write_values_yaml() {
  local app="$1"
  local valuesfile="$2"
  local image="$3"
  local ports_block="$4"
  local mounts_block="$5"
  local env_block="$6"
  local gpu_block="$7"

  cat > "$valuesfile" <<EOF
replicaCount: 1
image:
  repository: ${image}
  pullPolicy: IfNotPresent
service:
${ports_block}
persistence:
${mounts_block}
env:
${env_block}
${gpu_block}
EOF
}

# helper: format ports
format_ports_block() {
  local -n p_ref=$1
  local out="  ports:"
  for p in "${p_ref[@]}"; do
    host="${p%%:*}"
    cont="${p##*:}"
    out+="
    - name: port-${cont}
      port: ${cont}
      targetPort: ${cont}
      nodePort: ${host}"
  done
  echo "$out"
}

# helper: format mounts
format_mounts_block() {
  local -n v_ref=$1
  local out="  enabled: true
  mounts:"
  for v in "${v_ref[@]}"; do
    host="${v%%:*}"
    cont="${v#*:}"
    name=$(basename "$cont" | tr '/ ' '__' )
    out+="
    - name: ${name}
      mountPath: ${cont}
      hostPath: ${host}"
  done
  echo "$out"
}

# helper: format env
format_env_block() {
  local -n e_ref=$1
  local out=""
  for e in "${e_ref[@]}"; do
    key="${e%%=*}"
    val="${e#*=}"
    out+="  - name: ${key}
    value: \"${val}\"
"
  done
  echo "$out"
}

# Build app definitions and write charts/values, overwrite if present
for app in "${APPLIST[@]}"; do
  APP_DIR="$BASE_APPS_DIR/$app"
  CHART_FILE="$APP_DIR/Chart.yaml"
  VALUES_FILE="$APP_DIR/values.yaml"

  # Overwrite warning
  if [ -f "$CHART_FILE" ]; then
    echo "⚠️  $CHART_FILE exists — will overwrite"
  fi
  if [ -f "$VALUES_FILE" ]; then
    echo "⚠️  $VALUES_FILE exists — will overwrite"
  fi

  # Default per-app config
  case "$app" in
    jellyfin)
      IMAGE="lscr.io/linuxserver/jellyfin:latest"
      PORTS=("8096:8096")
      VOLUMES=("${BASE_APPS_DIR}/jellyfin:/config" "${BASE_MEDIA_DIR}:/media")
      ENVS=("PUID=${PUID}" "PGID=${PGID}")
      ;;
    sonarr)
      IMAGE="linuxserver/sonarr:latest"
      PORTS=("8989:8989")
      VOLUMES=("${BASE_APPS_DIR}/sonarr:/config" "${BASE_MEDIA_DIR}:/media")
      ENVS=("PUID=${PUID}" "PGID=${PGID}" "SONARR_ROOTFOLDER=/media/tv")
      ;;
    radarr)
      IMAGE="linuxserver/radarr:latest"
      PORTS=("7878:7878")
      VOLUMES=("${BASE_APPS_DIR}/radarr:/config" "${BASE_MEDIA_DIR}:/media")
      ENVS=("PUID=${PUID}" "PGID=${PGID}" "RADARR_ROOTFOLDER=/media/movies")
      ;;
    tdarr)
      IMAGE="haveagitgat/tdarr:latest"
      PORTS=("8265:8265" "8266:8266")
      VOLUMES=("${BASE_APPS_DIR}/tdarr:/app/config" "${BASE_MEDIA_DIR}:/media")
      ENVS=("PUID=${PUID}" "PGID=${PGID}" "TDARR_CACHE=/app/config/transcode_cache")
      ;;
    prowlarr)
      IMAGE="linuxserver/prowlarr:latest"
      PORTS=("9696:9696")
      VOLUMES=("${BASE_APPS_DIR}/prowlarr:/config" "${BASE_MEDIA_DIR}:/media")
      ENVS=("PUID=${PUID}" "PGID=${PGID}")
      ;;
    qbittorrent)
      IMAGE="lscr.io/linuxserver/qbittorrent:latest"
      PORTS=("10080:10080")
      VOLUMES=("${BASE_APPS_DIR}/qbittorrent:/config" "${BASE_MEDIA_DIR}:/media")
      ENVS=(
        "PUID=${PUID}"
        "PGID=${PGID}"
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
        "DHT=false"
        "PEER_EXCHANGE=false"
        "LOCAL_PEER_DISCOVERY=false"
        "RSS_REFRESH_INTERVAL=30"
        "RSS_MAX_ARTICLES=500"
        "RSS_AUTO_DOWNLOAD=true"
        "TORRENT_MODE=automatic"
        "DEFAULT_SAVE_PATH=/media/Downloads/Completed"
      )
      ;;
    jellyseerr)
      IMAGE="fallenbagel/jellyseerr:latest"
      PORTS=("5055:5055")
      VOLUMES=("${BASE_APPS_DIR}/jellyseerr:/app/config" "${BASE_MEDIA_DIR}:/media")
      ENVS=("PUID=${PUID}" "PGID=${PGID}")
      ;;
    bazarr)
      IMAGE="linuxserver/bazarr:latest"
      PORTS=("6767:6767")
      VOLUMES=("${BASE_APPS_DIR}/bazarr:/config" "${BASE_MEDIA_DIR}:/media")
      ENVS=("PUID=${PUID}" "PGID=${PGID}")
      ;;
    dozzle)
      IMAGE="amir20/dozzle:latest"
      PORTS=("8888:8080")
      VOLUMES=("${BASE_APPS_DIR}/dozzle:/data")
      ENVS=()
      ;;
    recyclarr)
      IMAGE="ghcr.io/recyclarr/recyclarr:latest"
      PORTS=()
      VOLUMES=("${BASE_APPS_DIR}/recyclarr:/config" "${BASE_MEDIA_DIR}:/media")
      ENVS=("PUID=${PUID}" "PGID=${PGID}")
      ;;
    flaresolverr)
      IMAGE="ghcr.io/flaresolverr/flaresolverr:latest"
      PORTS=("8191:8191")
      VOLUMES=()
      ENVS=("LOG_LEVEL=info" "LOG_HTML=false" "CAPTCHA_SOLVER=none")
      ;;
    watchtower)
      IMAGE="containrrr/watchtower:latest"
      PORTS=()
      VOLUMES=("${BASE_APPS_DIR}/watchtower:/config")
      ENVS=("TZ=Europe/Amsterdam" "WATCHTOWER_CLEANUP=true" "WATCHTOWER_INCLUDE_STOPPED=true" "WATCHTOWER_DISABLE_CONTAINERS=ix*" "WATCHTOWER_NO_STARTUP_MESSAGE=true" "WATCHTOWER_SCHEDULE=0 0 3 * * *")
      ;;
    *)
      echo "Unknown app $app - skipping"
      continue
      ;;
  esac

  # Generate Chart and values files (overwrite)
  write_chart_yaml "$app" "$CHART_FILE"

  ports_block="$(format_ports_block PORTS)"
  mounts_block="$(format_mounts_block VOLUMES)"
  env_block="$(format_env_block ENVS)"

  gpu_block=""
  if [[ "$GPU_TYPE" == "nvidia" && ( "$app" == "jellyfin" || "$app" == "tdarr" ) ]]; then
    # Provide a simple GPU reservation block for values.yaml. TrueNAS UI may surface this.
    gpu_block="resources:
  reservations:
    devices:
      - driver: nvidia
        count: \"all\"
        capabilities: [gpu]
nvidia:
  visible_devices: \"${NVIDIA_VISIBLE}\""
  fi

  write_values_yaml "$app" "$VALUES_FILE" "$IMAGE" "$ports_block" "$mounts_block" "$env_block" "$gpu_block"

  echo "Generated: $CHART_FILE and $VALUES_FILE"
done

# Ensure ownership of all created files & folders to apps UID/GID
echo "Setting ownership to ${PUID}:${PGID} for $BASE_APPS_DIR and $BASE_MEDIA_DIR"
chown -R "${PUID}:${PGID}" "$BASE_APPS_DIR" || true
chown -R "${PUID}:${PGID}" "$BASE_MEDIA_DIR" || true
chmod -R 770 "$BASE_APPS_DIR" || true
chmod -R 770 "$BASE_MEDIA_DIR" || true

# Check for required tools before attempting deploy
if ! command -v ${K3S_KUBECTL%% *} &> /dev/null; then
  echo
  echo "⚠️  k3s kubectl not found in PATH. The script generated YAMLs but will NOT attempt deployment."
  echo "If you want to deploy from this host, run from SCALE shell where 'k3s kubectl' is available or install k3s kubectl."
  exit 0
fi

if ! command -v "${HELM_BIN}" &> /dev/null; then
  echo
  echo "⚠️  helm not found. The script generated YAMLs but will NOT attempt helm templating/deployment."
  echo "Install helm on this host or run deployment steps manually in SCALE shell."
  exit 0
fi

# Deploy each app: cleanup old resources then helm template -> k3s kubectl apply
for app in "${APPLIST[@]}"; do
  APP_DIR="$BASE_APPS_DIR/$app"
  CHART_FILE="$APP_DIR/Chart.yaml"
  VALUES_FILE="$APP_DIR/values.yaml"

  if [[ ! -f "$CHART_FILE" || ! -f "$VALUES_FILE" ]]; then
    echo "Skipping deploy for $app: missing Chart/values"
    continue
  fi

  echo
  echo "=== Deploying $app (cleaning prior resources) ==="

  # Attempt to delete old pod/deployment/service (ignore errors)
  echo "Deleting old pods, deployments and services for $app (if any)..."
  ${K3S_KUBECTL} -n "${SCALE_NAMESPACE}" delete pod,deploy,svc -l "app=${app}" --ignore-not-found=true || true
  ${K3S_KUBECTL} -n "${SCALE_NAMESPACE}" delete deployment "${app}" --ignore-not-found=true || true
  ${K3S_KUBECTL} -n "${SCALE_NAMESPACE}" delete service "${app}" --ignore-not-found=true || true

  # Create a temporary helm chart dir to template
  TMPDIR=$(mktemp -d)
  cp "$CHART_FILE" "${TMPDIR}/Chart.yaml"
  cp "$VALUES_FILE" "${TMPDIR}/values.yaml"

  # Produce Kubernetes manifests via helm template
  helm template "${app}" "${TMPDIR}" > "${TMPDIR}/manifests.yaml"

  # Apply manifests into the SCALE namespace
  echo "Applying manifests for $app into namespace ${SCALE_NAMESPACE}..."
  ${K3S_KUBECTL} apply -f "${TMPDIR}/manifests.yaml" -n "${SCALE_NAMESPACE}"

  # Cleanup
  rm -rf "$TMPDIR"
  echo "Deployed $app"
done

echo
echo "=== All done. Generated and (where possible) deployed apps. ==="
echo "If any deploy step failed, run the following from the TrueNAS SCALE shell (system shell):"
echo "  k3s kubectl get pods -n ${SCALE_NAMESPACE}"
echo "To manually inspect generated files:"
echo "  ls -R ${BASE_APPS_DIR}"
echo
echo "Notes:"
echo " - If you ran as a non-SCALE shell, switch to TrueNAS Web UI Shell before deploying."
echo " - If you prefer not to auto-delete prior resources, edit the script and remove the k3s kubectl delete lines."
echo
