#!/bin/bash

# Permanent pool names
CONFIG_POOL="APPS"
MEDIA_POOL="STORAGE"

# Retrieve private IP for CIDR (if needed)
PRIVATE_IP=$(hostname -I | awk '{print $1}')
CIDR_NETWORK="${PRIVATE_IP%.*}.0/24"

# Define datasets and directories
CONFIG_DATASETS=("prowlarr" "radarr" "sonarr" "jellyseerr" "profilarr" "bazarr" "jellyfin" "qbittorrent" "dozzle" "watchtower")
MEDIA_SUBDIRECTORIES=("movies" "tv" "downloads" "incomplete" "Completed" "Completed_Torrents")
DOCKER_COMPOSE_PATH="/mnt/$CONFIG_POOL/docker"
YAML_OUTPUT_DIR="$DOCKER_COMPOSE_PATH/yamls"

# Function to create dataset
create_dataset() {
    local pool="$1"
    local dataset="$2"
    local path="/mnt/$pool/$dataset"
    if [ ! -d "$path" ]; then
        echo "Creating dataset/directory: $path"
        mkdir -p "$path"
        chown root:apps "$path"
        chmod 770 "$path"
    fi
}

# Create config datasets
for dataset in "${CONFIG_DATASETS[@]}"; do
    create_dataset "$CONFIG_POOL" "$dataset"
done

# Create media directories
for subdir in "${MEDIA_SUBDIRECTORIES[@]}"; do
    create_dataset "$MEDIA_POOL/media" "$subdir"
done

# Ensure YAML output dir exists
mkdir -p "$YAML_OUTPUT_DIR"

# Function to write YAML
write_yaml() {
    local app_name="$1"
    local yaml_content="$2"
    local file="$YAML_OUTPUT_DIR/$app_name.yml"
    echo "$yaml_content" > "$file"
    echo "YAML for $app_name written to $file"
}

# --------------- YAML Definitions -----------------

# 1. Prowlarr
write_yaml "prowlarr" "--- 
version: '3'
services:
  prowlarr:
    image: linuxserver/prowlarr
    container_name: prowlarr
    restart: unless-stopped
    ports:
      - 9696:9696
    networks:
      - media_network
    volumes:
      - /mnt/$CONFIG_POOL/prowlarr:/config
      - /mnt/$MEDIA_POOL/media:/media
networks:
  media_network:
    driver: bridge
"

# 2. Radarr
write_yaml "radarr" "--- 
version: '3'
services:
  radarr:
    image: linuxserver/radarr
    container_name: radarr
    restart: unless-stopped
    ports:
      - 7878:7878
    environment:
      - PUID=568
      - PGID=568
      - TZ=Europe/Amsterdam
    networks:
      - media_network
    volumes:
      - /mnt/$CONFIG_POOL/radarr:/config
      - /mnt/$MEDIA_POOL/media:/media
networks:
  media_network:
    driver: bridge
"

# 3. Sonarr
write_yaml "sonarr" "--- 
version: '3'
services:
  sonarr:
    image: linuxserver/sonarr
    container_name: sonarr
    restart: unless-stopped
    ports:
      - 8989:8989
    environment:
      - PUID=568
      - PGID=568
      - TZ=Europe/Amsterdam
    networks:
      - media_network
    volumes:
      - /mnt/$CONFIG_POOL/sonarr:/config
      - /mnt/$MEDIA_POOL/media:/media
networks:
  media_network:
    driver: bridge
"

# 4. Jellyseerr
write_yaml "jellyseerr" "--- 
version: '3'
services:
  jellyseerr:
    image: fallenbagel/jellyseerr
    container_name: jellyseerr
    restart: unless-stopped
    ports:
      - 5055:5055
    environment:
      - TZ=Europe/Amsterdam
    networks:
      - media_network
    user: '568:568'
    volumes:
      - /mnt/$CONFIG_POOL/jellyseerr:/app/config
networks:
  media_network:
    driver: bridge
"

# 5. Profilarr
write_yaml "profilarr" "--- 
version: '3'
services:
  profilarr:
    image: santiagosayshey/profilarr:latest
    container_name: profilarr
    restart: unless-stopped
    ports:
      - 6868:6868
    environment:
      - TZ=Europe/Amsterdam
    networks:
      - media_network
    volumes:
      - /mnt/$CONFIG_POOL/profilarr:/config
networks:
  media_network:
    driver: bridge
"

# 6. Bazarr
write_yaml "bazarr" "--- 
version: '3'
services:
  bazarr:
    image: linuxserver/bazarr
    container_name: bazarr
    restart: unless-stopped
    ports:
      - 6767:6767
    environment:
      - PUID=568
      - PGID=568
      - TZ=Europe/Amsterdam
    networks:
      - media_network
    volumes:
      - /mnt/$CONFIG_POOL/bazarr:/config
      - /mnt/$MEDIA_POOL/media:/media
networks:
  media_network:
    driver: bridge
"

# 7. Jellyfin
write_yaml "jellyfin" "--- 
version: '3'
services:
  jellyfin:
    container_name: jellyfin
    image: lscr.io/linuxserver/jellyfin:latest
    restart: unless-stopped
    ports:
      - '8096:8096'
    environment:
      - PUID=568
      - PGID=568
      - TZ=Europe/Amsterdam
    networks:
      - media_network
    volumes:
      - /mnt/$CONFIG_POOL/jellyfin:/config
      - /mnt/$MEDIA_POOL/media:/media
networks:
  media_network:
    driver: bridge
"

# 8. qBittorrent
write_yaml "qbittorrent" "--- 
version: '3'
services:
  qbittorrent:
    container_name: qbittorrent
    image: ghcr.io/hotio/qbittorrent
    restart: unless-stopped
    ports:
      - 10080:10080
    environment:
      - PUID=568
      - PGID=568
      - UMASK=002
      - TZ=Europe/Amsterdam
      - WEBUI_PORT=10080
      - INCOMPLETE_DIR=/mnt/STORAGE/media/incomplete
      - COMPLETED_DIR=/mnt/STORAGE/media/Completed
      - COMPLETED_TORRENTS_DIR=/mnt/STORAGE/media/Completed_Torrents
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
    networks:
      - media_network
    volumes:
      - /mnt/$CONFIG_POOL/qbittorrent:/config
      - /mnt/$MEDIA_POOL/media:/media
networks:
  media_network:
    driver: bridge
"

# 9. Dozzle
write_yaml "dozzle" "--- 
version: '3'
services:
  dozzle:
    image: amir20/dozzle
    container_name: dozzle
    restart: unless-stopped
    ports:
      - '8888:8080'
    networks:
      - media_network
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /mnt/$CONFIG_POOL/dozzle:/data
networks:
  media_network:
    driver: bridge
"

# 10. Watchtower
write_yaml "watchtower" "--- 
version: '3'
services:
  watchtower:
    container_name: watchtower
    image: nickfedor/watchtower
    restart: unless-stopped
    environment:
      - TZ=Europe/Amsterdam
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_NOTIFICATIONS_HOSTNAME=TrueNAS
      - WATCHTOWER_INCLUDE_STOPPED=true
      - WATCHTOWER_DISABLE_CONTAINERS=ix*
      - WATCHTOWER_NO_STARTUP_MESSAGE=true
      - WATCHTOWER_SCHEDULE=0 0 3 * * *
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
networks:
  media_network:
    driver: bridge
"

echo "✅ All YAML files generated in $YAML_OUTPUT_DIR"
