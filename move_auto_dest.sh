#!/bin/bash

# Set how many directory levels to display in rsync output
LEVELS=2
REGEX="^./([^/]+/){0,$((LEVELS-1))}[^/]+|sent|Number of files transferred"

# Base source directory
BASE_SRC="/mnt/tank/storage-share/Media"

# Function to interactively drill down with next-level preview
select_directory() {
    local CURRENT_DIR="$1"
    while true; do
        # List current level subdirectories
        mapfile -t DIRS < <(find "$CURRENT_DIR" -mindepth 1 -maxdepth 1 -type d)
        if [ ${#DIRS[@]} -eq 0 ]; then
            echo "No further subdirectories in $CURRENT_DIR"
            break
        fi

        echo "Subdirectories in $CURRENT_DIR:"
        select DIR in "${DIRS[@]}"; do
            if [ -n "$DIR" ]; then
                echo "Selected: $DIR"

                # Preview next level subdirectories
                NEXT_LEVEL=$(find "$DIR" -mindepth 1 -maxdepth 1 -type d)
                if [ -n "$NEXT_LEVEL" ]; then
                    echo "Contents of the next level under $DIR:"
                    for d in $NEXT_LEVEL; do
                        echo "  $(basename "$d")"
                    done
                else
                    echo "No further subdirectories under $DIR"
                fi

                # Confirm with user
                read -p "Is this the directory you want to copy from? [y/N]: " CONFIRM
                if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
                    echo "Directory confirmed: $DIR"
                    echo "$DIR"
                    return
                else
                    # Drill down further
                    CURRENT_DIR="$DIR"
                    break
                fi
            else
                echo "Invalid selection. Try again."
            fi
        done
    done
    echo "$CURRENT_DIR"
}

# Start interactive selection
SRC=$(select_directory "$BASE_SRC")

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
