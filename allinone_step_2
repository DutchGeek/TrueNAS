#!/bin/bash

# Fixed pools/directories
APPS_POOL="/mnt/APPS"
STORAGE_POOL="/mnt/STORAGE"
PUID=568
PGID=568

# App directories
declare -A APPS_CONFIGS=(
    [qbittorrent]="$APPS_POOL/qbittorrent/config"
    [sonarr]="$APPS_POOL/sonarr/config"
    [radarr]="$APPS_POOL/radarr/config"
    [jellyfin]="$APPS_POOL/jellyfin/config"
    [prowlarr]="$APPS_POOL/prowlarr/config"
)

# Media directories
MEDIA_DIRS=(
    "$STORAGE_POOL/Downloads/Incomplete"
    "$STORAGE_POOL/Downloads/Completed"
    "$STORAGE_POOL/Downloads/Completed_Torrents"
)

# Function to create directories with ownership and permissions
create_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo "Creating directory: $dir"
        mkdir -p "$dir"
        chown $PUID:$PGID "$dir"
        chmod 770 "$dir"
    else
        echo "Directory exists: $dir"
        chown $PUID:$PGID "$dir"
        chmod 770 "$dir"
    fi
}

# Check and create app config directories
for app in "${!APPS_CONFIGS[@]}"; do
    create_directory "${APPS_CONFIGS[$app]}"
done

# Check and create media directories
for dir in "${MEDIA_DIRS[@]}"; do
    create_directory "$dir"
done

echo "All required directories exist with correct permissions."

# Optional: check for existing Docker containers
for app in "${!APPS_CONFIGS[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -qw "$app"; then
        echo "Docker container for $app exists."
    else
        echo "Docker container for $app not found. Will need deployment."
    fi
done

echo "Directory and container checks completed."
