#!/bin/bash

CONFIG_POOL="APPS"
MEDIA_POOL="STORAGE"
YAML_DIR="/mnt/$CONFIG_POOL/yaml"

# Create datasets/directories
mkdir -p "$YAML_DIR"
mkdir -p "/mnt/$CONFIG_POOL/configs"
mkdir -p "/mnt/$MEDIA_POOL/media/movies"
mkdir -p "/mnt/$MEDIA_POOL/media/tv"
mkdir -p "/mnt/$MEDIA_POOL/media/downloads"
chown -R root:apps "/mnt/$CONFIG_POOL" "/mnt/$MEDIA_POOL"
chmod -R 770 "/mnt/$CONFIG_POOL" "/mnt/$MEDIA_POOL"

echo "Directories and datasets created."

# Function to generate YAML
generate_yaml() {
  local app_name="$1"
  local image="$2"
  local ports=("${!3}")
  local volumes=("${!4}")
  local env_vars=("${!5}")

  cat > "$YAML_DIR/$app_name.yml" <<EOF
---
version: "3.8"
services:
  $app_name:
    container_name: $app_name
    image: $image
    restart: unless-stopped
    ports:
$(for p in "${ports[@]}"; do echo "      - \"$p\""; done)
    environment:
$(for e in "${env_vars[@]}"; do echo "      - $e"; done)
    volumes:
$(for v in "${volumes[@]}"; do echo "      - $v"; done)
EOF
  echo "Generated YAML for $app_name at $YAML_DIR/$app_name.yml"
}

# ======================
# Application definitions
# ======================

# qBittorrent
QB_PORTS=("10080:10080")
QB_VOLUMES=("/mnt/$CONFIG_POOL/configs/qbittorrent:/config" "/mnt/$MEDIA_POOL/media:/media")
QB_ENV=(
  "TZ=Europe/Amsterdam"
  "PUID=568"
  "PGID=568"
  "UMASK=002"
  "WEBUI_PORT=10080"
  "INCOMPLETE_DIR=/media/downloads"
  "COMPLETED_DIR=/media/completed"
  "COMPLETED_TORRENTS_DIR=/media/completed_torrents"
  "GLOBAL_MAX_CONNECTIONS=500"
  "MAX_CONNECTIONS_PER_TORRENT=100"
  "GLOBAL_MAX_UPLOADS=20"
  "MAX_UPLOADS_PER_TORRENT=4"
  "MAX_ACTIVE_DOWNLOADS=3"
  "MAX_ACTIVE_UPLOADS=100"
  "MAX_ACTIVE_TORRENTS=500"
  "COUNT_SLOW_TORRENTS=false"
  "TOTAL_SEED_TIME=50000"
  "DHT=false"
  "PEER_EXCHANGE=false"
  "LOCAL_PEER_DISCOVERY=false"
  "RSS_REFRESH_INTERVAL=30"
  "RSS_MAX_ARTICLES=500"
  "RSS_AUTO_DOWNLOAD=true"
  "TORRENT_MODE=automatic"
)

generate_yaml "qbittorrent" "ghcr.io/hotio/qbittorrent" QB_PORTS[@] QB_VOLUMES[@] QB_ENV[@]

# Radarr
RADARR_PORTS=("7878:7878")
RADARR_VOLUMES=("/mnt/$CONFIG_POOL/configs/radarr:/config" "/mnt/$MEDIA_POOL/media:/media")
RADARR_ENV=("TZ=Europe/Amsterdam" "PUID=568" "PGID=568")
generate_yaml "radarr" "linuxserver/radarr" RADARR_PORTS[@] RADARR_VOLUMES[@] RADARR_ENV[@]

# Sonarr
SONARR_PORTS=("8989:8989")
SONARR_VOLUMES=("/mnt/$CONFIG_POOL/configs/sonarr:/config" "/mnt/$MEDIA_POOL/media:/media")
SONARR_ENV=("TZ=Europe/Amsterdam" "PUID=568" "PGID=568")
generate_yaml "sonarr" "linuxserver/sonarr" SONARR_PORTS[@] SONARR_VOLUMES[@] SONARR_ENV[@]

# Jellyfin
JELLYFIN_PORTS=("8096:8096")
JELLYFIN_VOLUMES=("/mnt/$CONFIG_POOL/configs/jellyfin:/config" "/mnt/$MEDIA_POOL/media:/media")
JELLYFIN_ENV=("TZ=Europe/Amsterdam" "PUID=568" "PGID=568")
generate_yaml "jellyfin" "lscr.io/linuxserver/jellyfin:latest" JELLYFIN_PORTS[@] JELLYFIN_VOLUMES[@] JELLYFIN_ENV[@]

# Prowlarr
PROWLARR_PORTS=("9696:9696")
PROWLARR_VOLUMES=("/mnt/$CONFIG_POOL/configs/prowlarr:/config" "/mnt/$MEDIA_POOL/media:/media")
PROWLARR_ENV=("TZ=Europe/Amsterdam")
generate_yaml "prowlarr" "linuxserver/prowlarr" PROWLARR_PORTS[@] PROWLARR_VOLUMES[@] PROWLARR_ENV[@]

# Bazarr
BAZARR_PORTS=("6767:6767")
BAZARR_VOLUMES=("/mnt/$CONFIG_POOL/configs/bazarr:/config" "/mnt/$MEDIA_POOL/media:/media")
BAZARR_ENV=("TZ=Europe/Amsterdam" "PUID=568" "PGID=568")
generate_yaml "bazarr" "linuxserver/bazarr" BAZARR_PORTS[@] BAZARR_VOLUMES[@] BAZARR_ENV[@]

# Profilarr
PROFILARR_PORTS=("6868:6868")
PROFILARR_VOLUMES=("/mnt/$CONFIG_POOL/configs/profilarr:/config")
PROFILARR_ENV=("TZ=Europe/Amsterdam")
generate_yaml "profilarr" "santiagosayshey/profilarr:latest" PROFILARR_PORTS[@] PROFILARR_VOLUMES[@] PROFILARR_ENV[@]

# Jellyseerr
JELLYSEERR_PORTS=("5055:5055")
JELLYSEERR_VOLUMES=("/mnt/$CONFIG_POOL/configs/jellyseerr:/app/config")
JELLYSEERR_ENV=("TZ=Europe/Amsterdam")
generate_yaml "jellyseerr" "fallenbagel/jellyseerr" JELLYSEERR_PORTS[@] JELLYSEERR_VOLUMES[@] JELLYSEERR_ENV[@]

# Flaresolverr
FLARESOLVERR_PORTS=("8191:8191")
FLARESOLVERR_VOLUMES=()
FLARESOLVERR_ENV=("TZ=Europe/Amsterdam" "LOG_LEVEL=info")
generate_yaml "flaresolverr" "ghcr.io/flaresolverr/flaresolverr:latest" FLARESOLVERR_PORTS[@] FLARESOLVERR_VOLUMES[@] FLARESOLVERR_ENV[@]

# Dozzle
DOZZLE_PORTS=("8888:8080")
DOZZLE_VOLUMES=("/var/run/docker.sock:/var/run/docker.sock" "/mnt/$CONFIG_POOL/configs/dozzle:/data")
DOZZLE_ENV=()
generate_yaml "dozzle" "amir20/dozzle" DOZZLE_PORTS[@] DOZZLE_VOLUMES[@] DOZZLE_ENV[@]

# Watchtower
WATCHTOWER_PORTS=()
WATCHTOWER_VOLUMES=("/var/run/docker.sock:/var/run/docker.sock")
WATCHTOWER_ENV=("TZ=Europe/Amsterdam" "WATCHTOWER_CLEANUP=true" "WATCHTOWER_INCLUDE_STOPPED=true" "WATCHTOWER_NO_STARTUP_MESSAGE=true")
generate_yaml "watchtower" "containrrr/watchtower" WATCHTOWER_PORTS[@] WATCHTOWER_VOLUMES[@] WATCHTOWER_ENV[@]

echo "✅ All YAML files are generated in $YAML_DIR"
echo "Copy/paste each YAML file into TrueNAS SCALE 'Install via YAML' interface per app."
