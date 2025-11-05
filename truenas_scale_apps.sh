#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# TrueNAS SCALE Apps generator
# -------------------------------

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
