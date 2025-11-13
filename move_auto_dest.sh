#!/bin/bash

# Set how many directory levels to display in rsync output (e.g., 2)
LEVELS=2

# Build regex pattern for grep
REGEX="^./([^/]+/){0,$((LEVELS-1))}[^/]+|sent|Number of files transferred"

# Base source directory
BASE_SRC="/mnt/tank/media"

# Find directories up to 3 levels deep for selection
echo "Available source directories (up to 3 levels deep) under $BASE_SRC:"
mapfile -t DIRS < <(find "$BASE_SRC" -mindepth 1 -maxdepth 3 -type d)

# Present selection menu
PS3="Select the source directory to move: "
select SRC in "${DIRS[@]}"; do
    if [ -n "$SRC" ]; then
        echo "Selected source: $SRC"
        break
    else
        echo "Invalid selection. Try again."
    fi
done

# Auto-suggest destination folder based on source, lowercase
SRC_BASENAME=$(basename "$SRC")
DST_SUGGEST=$(echo "$SRC_BASENAME" | tr '[:upper:]' '[:lower:]')
read -p "Enter destination folder name (default: $DST_SUGGEST, under /mnt/tank/media): " DST_SUB
DST_SUB=${DST_SUB:-$DST_SUGGEST}
DST="/mnt/tank/media/$DST_SUB"

# Create destination if it doesn't exist
mkdir -p "$DST"

# Summary of source
echo "Scanning source directory for summary..."
TOTAL_DIRS=$(find "$SRC" -type d | wc -l)
TOTAL_FILES=$(find "$SRC" -type f | wc -l)
echo "Total directories: $TOTAL_DIRS"
echo "Total files: $TOTAL_FILES"

# Dry run
echo "Starting dry run..."
rsync -aAXn --remove-source-files --info=progress2,stats2 --partial "$SRC/" "$DST/" | grep -E "$REGEX"

echo "Dry run complete. Review output above."
read -p "Press Enter to start actual move…"

# Actual move
rsync -aAX --remove-source-files --info=progress2,stats2 --partial "$SRC/" "$DST/" | grep -E "$REGEX"

# Clean empty directories in source
find "$SRC" -type d -empty -delete

echo "Move complete and empty directories cleaned!"
