#!/bin/bash

# Permanent pools
CONFIG_POOL="APPS"
MEDIA_POOL="STORAGE"

# Retrieve the private IP address of the server and convert it to CIDR notation
PRIVATE_IP=$(hostname -I | awk '{print $1}')
CIDR_NETWORK="${PRIVATE_IP%.*}.0/24"

# Define datasets and directories (all lowercase except pool names)
CONFIG_DATASETS=("prowlarr" "radarr" "sonarr" "jellyseerr" "profilarr" "bazarr" "jellyfin" "qbittorrent" "dozzle")
MEDIA_SUBDIRECTORIES=("movies" "tv" "downloads" "incomplete" "completed" "completed_torrents")
DOCKER_COMPOSE_PATH="/mnt/$CONFIG_POOL/docker"
YAML_PATH="$DOCKER_COMPOSE_PATH/yamls"
QBITTORRENT_CONFIG_DIR="/mnt/$CONFIG_POOL/configs/qbittorrent"

# Prompt for NVIDIA GPU usage
read -p "Do you have an NVIDIA GPU you want to pass through to containers? (yes/no): " USE_NVIDIA
USE_NVIDIA=$(echo "$USE_NVIDIA" | tr '[:upper:]' '[:lower:]')

# Function to create dataset
create_dataset() {
    local pool_name="$1"
    local dataset_name="$2"
    local dataset_path="$pool_name/$(echo "$dataset_name" | tr '[:upper:]' '[:lower:]')"
    local mountpoint="/mnt/$dataset_path"

    if ! zfs list "$dataset_path" >/dev/null 2>&1; then
        echo "Creating dataset: $dataset_path"
        zfs create "$dataset_path"
    fi

    # Ensure mount
    if ! mountpoint -q "$mountpoint"; then
        zfs mount "$dataset_path"
    fi

    if [ -d "$mountpoint" ]; then
        chown root:apps "$mountpoint"
        chmod 770 "$mountpoint"
    fi
}

# Function to create directories
create_directory() {
    local dir="$1"
    dir=$(echo "$dir" | tr '[:upper:]' '[:lower:]')
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        chown root:apps "$dir"
        chmod 770 "$dir"
    else
        chown root:apps "$dir"
        chmod 770 "$dir"
    fi
}

# Create config datasets
create_dataset "$CONFIG_POOL" "configs"
for dataset in "${CONFIG_DATASETS[@]}"; do
    create_dataset "$CONFIG_POOL" "configs/$dataset"
done

# Create media dataset
create_dataset "$MEDIA_POOL" "media"
for subdir in "${MEDIA_SUBDIRECTORIES[@]}"; do
    create_directory "/mnt/$MEDIA_POOL/media/$subdir"
done

# Ensure Docker Compose and YAML directories
create_directory "$DOCKER_COMPOSE_PATH"
create_directory "$YAML_PATH"

# Generate YAMLs for each app
generate_yaml() {
    local app="$1"
    local image="$2"
    local ports="$3"
    local extra_env="$4"
    local volumes="$5"
    local container_name="$app"

    # NVIDIA option
    local runtime_line=""
    if [ "$USE_NVIDIA" = "yes" ]; then
        runtime_line="runtime: nvidia"
    fi

    cat > "$YAML_PATH/$app.yaml" <<EOF
version: '3'
services:
  $container_name:
    image: $image
    container_name: $container_name
    restart: unless-stopped
    ports:
      - $ports
    environment:
      - TZ=Europe/Amsterdam
      - PUID=568
      - PGID=568
$extra_env
    volumes:
$volumes
    $runtime_line
networks:
  media_network:
    driver: bridge
EOF
    echo "YAML for $app generated at $YAML_PATH/$app.yaml"
}

# Prowlarr
generate_yaml "prowlarr" "linuxserver/prowlarr" "9696:9696" "" "      - /mnt/$CONFIG_POOL/configs/prowlarr:/config\n      - /mnt/$MEDIA_POOL/media:/media"

# Radarr
generate_yaml "radarr" "linuxserver/radarr" "7878:7878" "" "      - /mnt/$CONFIG_POOL/configs/radarr:/config\n      - /mnt/$MEDIA_POOL/media:/media"

# Sonarr
generate_yaml "sonarr" "linuxserver/sonarr" "8989:8989" "" "      - /mnt/$CONFIG_POOL/configs/sonarr:/config\n      - /mnt/$MEDIA_POOL/media:/media"

# Jellyseerr
generate_yaml "jellyseerr" "fallenbagel/jellyseerr" "5055:5055" "      - USER=568:568" "      - /mnt/$CONFIG_POOL/configs/jellyseerr:/app/config"

# Profilarr
generate_yaml "profilarr" "santiagosayshey/profilarr:latest" "6868:6868" "" "      - /mnt/$CONFIG_POOL/configs/profilarr:/config"

# Bazarr
generate_yaml "bazarr" "linuxserver/bazarr" "6767:6767" "" "      - /mnt/$CONFIG_POOL/configs/bazarr:/config\n      - /mnt/$MEDIA_POOL/media:/media"

# Jellyfin
generate_yaml "jellyfin" "lscr.io/linuxserver/jellyfin:latest" "8096:8096" "" "      - /mnt/$CONFIG_POOL/configs/jellyfin:/config\n      - /mnt/$MEDIA_POOL/media:/media"

# Qbittorrent
QBT_EXTRA_ENV=$(cat <<EOF
      - WEBUI_PORT=10080
      - INCOMPLETE_DIR=/mnt/$MEDIA_POOL/media/incomplete
      - COMPLETED_DIR=/mnt/$MEDIA_POOL/media/completed
      - COMPLETED_TORRENTS_DIR=/mnt/$MEDIA_POOL/media/completed_torrents
      - GLOBAL_MAX_CONNECTIONS=500
      - MAX_CONNECTIONS_PER_TORRENT=100
      - GLOBAL_MAX_UPLOADS=20
      - MAX_UPLOADS_PER_TORRENT=4
      - MAX_ACTIVE_DOWNLOADS=3
      - MAX_ACTIVE_UPLOADS=100
      - MAX_ACTIVE_TORRENTS=500
      - COUNT_SLOW_TORRENTS=false
      - TOTAL_SEED_TIME=50000
      - DHT=false
      - PEER_EXCHANGE=false
      - LOCAL_PEER_DISCOVERY=false
      - RSS_REFRESH_INTERVAL=30
      - RSS_MAX_ARTICLES=500
      - RSS_AUTO_DOWNLOAD=true
      - TORRENT_MODE=automatic
EOF
)
generate_yaml "qbittorrent" "ghcr.io/hotio/qbittorrent" "10080:10080" "$QBT_EXTRA_ENV" "      - /mnt/$CONFIG_POOL/configs/qbittorrent:/config\n      - /mnt/$MEDIA_POOL/media:/media"

# Dozzle
generate_yaml "dozzle" "amir20/dozzle" "8888:8080" "" "      - /var/run/docker.sock:/var/run/docker.sock\n      - /mnt/$CONFIG_POOL/configs/dozzle:/data"

# Watchtower
generate_yaml "watchtower" "nickfedor/watchtower" "" "      - WATCHTOWER_CLEANUP=true\n      - WATCHTOWER_NOTIFICATIONS_HOSTNAME=TrueNAS\n      - WATCHTOWER_INCLUDE_STOPPED=true\n      - WATCHTOWER_DISABLE_CONTAINERS=ix*\n      - WATCHTOWER_NO_STARTUP_MESSAGE=true\n      - WATCHTOWER_SCHEDULE=0 0 3 * * *" "      - /var/run/docker.sock:/var/run/docker.sock"

echo "All YAML files generated in $YAML_PATH"
echo "You can now copy these into the TrueNAS Scale 'Install via YAML' interface."
