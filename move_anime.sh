#!/bin/bash

# Base paths
BASE_SRC="/mnt/tank/storage-share/Media/Anime/Series"
BASE_DST="/mnt/tank/media/anime/series"

echo "Welcome! This script will move everything under $BASE_SRC to $BASE_DST."

# Create destination folder if it doesn't exist
mkdir -p "$BASE_DST"

# Count directories and files before move
DIR_COUNT=$(find "$BASE_SRC" -type d | wc -l)
FILE_COUNT=$(find "$BASE_SRC" -type f | wc -l)

# Show what will be moved
echo -e "\nSource: $BASE_SRC"
echo "Destination: $BASE_DST"
echo "Directories to move: $DIR_COUNT"
echo "Files to move: $FILE_COUNT"

# Confirm before moving
read -p "Press Enter to start moving..."

# Move everything under Series
rsync -aAX --remove-source-files --info=progress2,stats2 --partial "$BASE_SRC/" "$BASE_DST/" \
    | grep -E 'sent|Number of files transferred|^./'

# Remove empty directories in source
find "$BASE_SRC" -type d -empty -delete

# Final summary
echo -e "\nMove complete!"
echo "Summary:"
echo "  Source: $BASE_SRC"
echo "  Destination: $BASE_DST"
echo "  Directories moved: $DIR_COUNT"
echo "  Files moved: $FILE_COUNT"
