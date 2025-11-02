#!/bin/bash
set -e

echo "=== TrueNAS Scale Bare Install App Setup ==="

# Hardcoded pools
POOL_APPS="APPS"
POOL_MEDIA="STORAGE"

# GPU default to None for bare install
GPU_TYPE="None"

# Ensure apps user/group
if ! id apps &>/dev/null; then
    echo "Creating apps group and user..."
    groupadd apps
    useradd -m -g apps apps
fi

# Base directories
BASE_APPS_DIR="/mnt/$POOL_APPS"
BASE_MEDIA_DIR="/mnt/$POOL_MEDIA"

# Create directories
mkdir -p "$BASE_APPS_DIR"
mkdir -p "$BASE_MEDIA_DIR"

MEDIA_SUBDIRS=("movies" "tv" "downloads" "Incomplete" "Completed" "Completed Torrents")
for sub in "${MEDIA_SUBDIRS[@]}"; do
    DIR="$BASE_MEDIA_DIR/$sub"
    mkdir -p "$DIR"
    chown apps:apps "$DIR"
    chmod 770 "$DIR"
done

# Tdarr subdirs
TDARR_SUBDIRS=("server" "logs" "transcode_cache")
for sub in "${TDARR_SUBDIRS[@]}"; do
    DIR="$BASE_APPS_DIR/tdarr/$sub"
    mkdir -p "$DIR"
    chown apps:apps "$DIR"
    chmod 770 "$DIR"
done

# Function to generate TrueNAS Scale App manifest
generate_app_manifest() {
    local appname="$1"
    local image="$2"
    local ports=("${!3}")
    local volumes=("${!4}")
    local envs=("${!5}")
    local gpu="$6"

    local APP_DIR="$BASE_APPS_DIR/$appname"
    mkdir -p "$APP_DIR"

    local YAML_FILE="$APP_DIR/$appname.yaml"

    echo "Generating manifest for $appname..."

    cat > "$YAML_FILE" <<EOF
apiVersion: apps.truenas.com/v1alpha1
kind: TrueNASApp
metadata:
  name: $appname
spec:
  image: $image
  restartPolicy: Always
  environment:
EOF

    for e in "${envs[@]}"; do
        echo "    - name: ${e%=*}" >> "$YAML_FILE"
        echo "      value: \"${e#*=}\"" >> "$YAML_FILE"
    done

    echo "  ports:" >> "$YAML_FILE"
    for p in "${ports[@]}"; do
        echo "    - containerPort: ${p%:*}" >> "$YAML_FILE"
        echo "      hostPort: ${p#*:}" >> "$YAML_FILE"
    done

    echo "  volumes:" >> "$YAML_FILE"
    for v in "${volumes[@]}"; do
        echo "    - containerPath: ${v%%:*}" >> "$YAML_FILE"
        echo "      hostPath: ${v#*:}" >> "$YAML_FILE"
    done

    if [[ "$gpu" == "nvidia" ]]; then
        echo "  resources:" >> "$YAML_FILE"
        echo "    reservations:" >> "$YAML_FILE"
        echo "      devices:" >> "$YAML_FILE"
        echo "        - driver: nvidia" >> "$YAML_FILE"
        echo "          count: all" >> "$YAML_FILE"
        echo "          capabilities: [gpu]" >> "$YAML_FILE"
    fi

    echo "Manifest generated: $YAML_FILE"
    echo
}

# App definitions
APPS=("jellyfin" "sonarr" "radarr" "tdarr" "prowlarr" "qbittorrent")

for app in "${APPS[@]}"; do
    case $app in
        jellyfin)
            IMAGE="lscr.io/linuxserver/jellyfin:latest"
            PORTS=("8096:8096")
            VOLUMES=("/mnt/$POOL_APPS/jellyfin:/config" "/mnt/$POOL_MEDIA:/media")
            ENVS=("PUID=568" "PGID=568" "TZ=Europe/Amsterdam")
            GPU_OPT="$GPU_TYPE"
            ;;
        sonarr)
            IMAGE="linuxserver/sonarr:latest"
            PORTS=("8989:8989")
            VOLUMES=("/mnt/$POOL_APPS/sonarr:/config" "/mnt/$POOL_MEDIA:/media")
            ENVS=("PUID=568" "PGID=568" "TZ=Europe/Amsterdam")
            GPU_OPT="None"
            ;;
        radarr)
            IMAGE="linuxserver/radarr:latest"
            PORTS=("7878:7878")
            VOLUMES=("/mnt/$POOL_APPS/radarr:/config" "/mnt/$POOL_MEDIA:/media")
            ENVS=("PUID=568" "PGID=568" "TZ=Europe/Amsterdam")
            GPU_OPT="None"
            ;;
        tdarr)
            IMAGE="haveagitgat/tdarr:latest"
            PORTS=("8265:8265" "8266:8266")
            VOLUMES=("/mnt/$POOL_APPS/tdarr:/app/config" "/mnt/$POOL_MEDIA:/media")
            ENVS=("PUID=568" "PGID=568" "TZ=Europe/Amsterdam" "TDARR_CACHE=/app/config/transcode_cache")
            GPU_OPT="$GPU_TYPE"
            ;;
        prowlarr)
            IMAGE="linuxserver/prowlarr:latest"
            PORTS=("9696:9696")
            VOLUMES=("/mnt/$POOL_APPS/prowlarr:/config" "/mnt/$POOL_MEDIA:/media")
            ENVS=("PUID=568" "PGID=568" "TZ=Europe/Amsterdam")
            GPU_OPT="None"
            ;;
        qbittorrent)
            IMAGE="ghcr.io/hotio/qbittorrent"
            PORTS=("10080:10080")
            VOLUMES=("/mnt/$POOL_APPS/qbittorrent:/config" "/mnt/$POOL_MEDIA:/media")
            ENVS=("PUID=568" "PGID=568" "UMASK=002" "TZ=Europe/Amsterdam" \
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
            GPU_OPT="None"
            ;;
    esac
    generate_app_manifest "$app" "$IMAGE" PORTS[@] VOLUMES[@] ENVS[@] "$GPU_OPT"
done

# Apply manifests
echo "=== Applying manifests to TrueNAS Scale Apps ==="
for app in "${APPS[@]}"; do
    YAML_FILE="$BASE_APPS_DIR/$app/$app.yaml"
    if [[ -f "$YAML_FILE" ]]; then
        echo "Applying $app manifest..."
        kubectl apply -f "$YAML_FILE" --namespace apps
    fi
done

echo "=== Waiting for pods to be ready ==="
for app in "${APPS[@]}"; do
    POD=""
    echo "Waiting for $app pod..."
    while [ -z "$POD" ]; do
        POD=$(kubectl get pods -n apps -l "app=$app" -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)
        sleep 2
    done
    kubectl wait --for=condition=Ready pod "$POD" -n apps --timeout=300s
done

echo "=== All pods are ready! ==="
HOST_IP=$(hostname -I | awk '{print $1}')
declare -A PORT_MAP=( ["jellyfin"]=8096 ["sonarr"]=8989 ["radarr"]=7878 ["tdarr"]=8265 ["prowlarr"]=9696 ["qbittorrent"]=10080 )

echo "Accessible URLs:"
for app in "${!PORT_MAP[@]}"; do
    echo "$app: http://$HOST_IP:${PORT_MAP[$app]}"
done

echo "=== TrueNAS Scale bare install completed! ==="
