#!/bin/bash

# Base source directory
BASE_SRC="/mnt/tank/storage-share/Media"
REGEX="^./([^/]+/){0,1}[^/]+|sent|Number of files transferred"

# Function to list subdirectories 1-level deep
get_subdirs() {
    local DIR="$1"
    local SUBS=()
    for d in "$DIR"/*/; do
        [ -d "$d" ] && SUBS+=("$d")
    done
    echo "${SUBS[@]}"
}

# Function: interactive directory selection using 'select'
select_directory() {
    local CURRENT="$1"
    while true; do
        SUBS=($(get_subdirs "$CURRENT"))
        if [ ${#SUBS[@]} -eq 0 ]; then
            echo "No subdirectories under $CURRENT"
            echo "$CURRENT"
            return
        fi

        echo -e "\nAvailable directories under $CURRENT:"
        select DIR in "${SUBS[@]}"; do
            [ -n "$DIR" ] || { echo "Invalid selection. Try again."; continue; }
            echo -e "\nYou've selected: $DIR"
            # Show 1-level contents
            echo "Contents of this directory (1 level deep):"
            for SUB in "$DIR"/*/; do
                [ -d "$SUB" ] || continue
                FILE_COUNT=$(find "$SUB" -maxdepth 1 -type f | wc -l)
                printf "  %s (%d files)\n" "$(basename "$SUB")" "$FILE_COUNT"
            done
            echo -n "Is this the directory you want to copy from? [y/N]: "
            read CONFIRM
            if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
                echo "$DIR"
                return
            else
                CURRENT="$DIR"
                break
            fi
        done
    done
}

# --- Start Script ---
echo "Welcome! This script will move directories under $BASE_SRC."

# Select source directory
SRC=$(select_directory "$BASE_SRC")
echo -e "\nDirectory confirmed: $SRC"

# Compute destination suggestion
REL_PATH="${SRC#$BASE_SRC/}"
DST_SUGGEST=$(echo "$REL_PATH" | tr '[:upper:]' '[:lower:]')
echo -n "Enter destination folder name (default: $DST_SUGGEST, under /mnt/tank/media): "
read DST_SUB
DST_SUB=${DST_SUB:-$DST_SUGGEST}
DST="/mnt/tank/media/$DST_SUB"

# Ensure destination exists
mkdir -p "$DST"

# Show summary of source
echo -e "\nScanning source directory for summary..."
TOTAL_DIRS=$(find "$SRC" -type d | wc -l)
TOTAL_FILES=$(find "$SRC" -type f | wc -l)
echo "Total directories: $TOTAL_DIRS"
echo "Total files: $TOTAL_FILES"

# Dry run
echo -e "\nStarting dry run..."
rsync -aAXn --remove-source-files --info=progress2,stats2 --partial "$SRC/" "$DST/" | grep -E "$REGEX"

echo -e "\nDry run complete. Review output above."
echo -n "Press Enter to start actual move…"
read

# Actual move
rsync -aAX --remove-source-files --info=progress2,stats2 --partial "$SRC/" "$DST/" | grep -E "$REGEX"

# Clean empty directories in source
find "$SRC" -type d -empty -delete

echo -e "\nMove complete and empty directories cleaned!"
