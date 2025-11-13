#!/bin/bash
#
# move_anime.sh — Moves Anime series directories from the main Media share to the target media directory
# Designed for TrueNAS Command Tasks (non-interactive)
#

SRC_BASE="/mnt/tank/storage-share/Media/Anime/Series"
DST_BASE="/mnt/tank/media/anime/series"
LOGFILE="/var/log/move_anime.log"

echo "========== $(date) ==========" >> "$LOGFILE"
echo "Starting move task..." >> "$LOGFILE"
echo "Source: $SRC_BASE" >> "$LOGFILE"
echo "Destination: $DST_BASE" >> "$LOGFILE"

# Check if source exists
if [ ! -d "$SRC_BASE" ]; then
  echo "Source directory not found: $SRC_BASE" >> "$LOGFILE"
  exit 1
fi

# Ensure destination exists
mkdir -p "$DST_BASE"

# Perform rsync move
rsync -av --remove-source-files --ignore-existing "$SRC_BASE"/ "$DST_BASE"/ >> "$LOGFILE" 2>&1

# Remove empty directories left behind
find "$SRC_BASE" -type d -empty -delete >> "$LOGFILE" 2>&1

echo "Move completed successfully." >> "$LOGFILE"
echo "" >> "$LOGFILE"

exit 0
