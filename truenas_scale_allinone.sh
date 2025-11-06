#!/bin/bash

# =========================
# TrueNAS SCALE All-in-One
# =========================
# Ensures directories exist, sets ownership, checks containers, and outputs YAMLs.

# Pools/directories
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

# -------------------------
# Function: create directories
# -------------------------
create_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo "Creating directory: $dir"
        mkdir -p "$dir"
    else
        echo "Directory exists: $dir"
    fi
    chown $PUID:$PGID "$dir"
    chmod 770 "$dir"
}

# -------------------------
# Create directories
# -------------------------
echo "Creating app config directories..."
for app in "${!APPS_CONFIGS[@]}"; do
    create_directory "${APPS_CONFIGS[$app]}"
done

echo "Creating media directories..."
for dir in "${MEDIA_DIRS[@]}"; do
    create_directory "$dir"
done

echo "All required directories exist with correct permissions."

# -------------------------
# Check existing Docker containers
# -------------------------
echo "Checking existing Docker containers..."
for app in "${!APPS_CONFIGS[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -qw "$app"; then
        echo "Docker container for $app exists."
    else
        echo "Docker container for $app not found. Ready for deployment."
    fi
done

# -------------------------
# Generate YAMLs for TrueNAS SCALE Install via YAML
# -------------------------
echo ""
echo "========================"
echo "qbittorrent YAML:"
echo "========================"
cat <<EOF
apiVersion: ixsystems.com/v1alpha1
kind: App
metadata:
  name: qbittorrent
spec:
  workload:
    type: Deployment
    podSpec:
      containers:
        - name: qbittorrent
          image: linuxserver/qbittorrent:latest
          env:
            PUID: "$PUID"
            PGID: "$PGID"
            TZ: "Europe/Amsterdam"
            WEBUI_PORT: "10080"
          ports:
            - name: webui
              port: 10080
              targetPort: 10080
          volumeMounts:
            - mountPath: /config
              name: config
            - mountPath: /downloads/Incomplete
              name: incomplete
            - mountPath: /downloads/Completed
              name: completed
            - mountPath: /downloads/Completed_Torrents
              name: completed_torrents
  service:
    type: NodePort
    ports:
      - name: webui
        port: 10080
        targetPort: 10080
  storage:
    config:
      type: hostPath
      hostPath: ${APPS_CONFIGS[qbittorrent]}
    incomplete:
      type: hostPath
      hostPath: ${MEDIA_DIRS[0]}
    completed:
      type: hostPath
      hostPath: ${MEDIA_DIRS[1]}
    completed_torrents:
      type: hostPath
      hostPath: ${MEDIA_DIRS[2]}
EOF

echo ""
echo "========================"
echo "sonarr YAML:"
echo "========================"
cat <<EOF
apiVersion: ixsystems.com/v1alpha1
kind: App
metadata:
  name: sonarr
spec:
  workload:
    type: Deployment
    podSpec:
      containers:
        - name: sonarr
          image: linuxserver/sonarr:latest
          env:
            PUID: "$PUID"
            PGID: "$PGID"
            TZ: "Europe/Amsterdam"
          ports:
            - name: web
              port: 8989
              targetPort: 8989
          volumeMounts:
            - mountPath: /config
              name: config
            - mountPath: /media
              name: media
  service:
    type: NodePort
    ports:
      - name: web
        port: 8989
        targetPort: 8989
  storage:
    config:
      type: hostPath
      hostPath: ${APPS_CONFIGS[sonarr]}
    media:
      type: hostPath
      hostPath: $STORAGE_POOL
EOF

echo ""
echo "========================"
echo "radarr YAML:"
echo "========================"
cat <<EOF
apiVersion: ixsystems.com/v1alpha1
kind: App
metadata:
  name: radarr
spec:
  workload:
    type: Deployment
    podSpec:
      containers:
        - name: radarr
          image: linuxserver/radarr:latest
          env:
            PUID: "$PUID"
            PGID: "$PGID"
            TZ: "Europe/Amsterdam"
          ports:
            - name: web
              port: 7878
              targetPort: 7878
          volumeMounts:
            - mountPath: /config
              name: config
            - mountPath: /media
              name: media
  service:
    type: NodePort
    ports:
      - name: web
        port: 7878
        targetPort: 7878
  storage:
    config:
      type: hostPath
      hostPath: ${APPS_CONFIGS[radarr]}
    media:
      type: hostPath
      hostPath: $STORAGE_POOL
EOF

echo ""
echo "========================"
echo "jellyfin YAML:"
echo "========================"
cat <<EOF
apiVersion: ixsystems.com/v1alpha1
kind: App
metadata:
  name: jellyfin
spec:
  workload:
    type: Deployment
    podSpec:
      containers:
        - name: jellyfin
          image: lscr.io/linuxserver/jellyfin:latest
          env:
            PUID: "$PUID"
            PGID: "$PGID"
            TZ: "Europe/Amsterdam"
          ports:
            - name: web
              port: 8096
              targetPort: 8096
          volumeMounts:
            - mountPath: /config
              name: config
            - mountPath: /media
              name: media
  service:
    type: NodePort
    ports:
      - name: web
        port: 8096
        targetPort: 8096
  storage:
    config:
      type: hostPath
      hostPath: ${APPS_CONFIGS[jellyfin]}
    media:
      type: hostPath
      hostPath: $STORAGE_POOL
EOF

echo ""
echo "========================"
echo "prowlarr YAML:"
echo "========================"
cat <<EOF
apiVersion: ixsystems.com/v1alpha1
kind: App
metadata:
  name: prowlarr
spec:
  workload:
    type: Deployment
    podSpec:
      containers:
        - name: prowlarr
          image: linuxserver/prowlarr:latest
          env:
            PUID: "$PUID"
            PGID: "$PGID"
            TZ: "Europe/Amsterdam"
          ports:
            - name: web
              port: 9696
              targetPort: 9696
          volumeMounts:
            - mountPath: /config
              name: config
  service:
    type: NodePort
    ports:
      - name: web
        port: 9696
        targetPort: 9696
  storage:
    config:
      type: hostPath
      hostPath: ${APPS_CONFIGS[prowlarr]}
EOF

echo ""
echo "All YAMLs generated. Copy each block into TrueNAS SCALE → Apps → Install via YAML."
echo "Script complete."
