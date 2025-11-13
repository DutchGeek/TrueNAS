#!/bin/bash

# Base source directory
BASE_SRC="/mnt/tank/storage-share/Media"
REGEX="^./([^/]+/){0,1}[^/]+|sent|Number of files transferred"

# Function: list 1-level subdirectories with file counts
list_dirs() {
    local DIR="$1"
    DIRS=()
    local i=1
    for SUB in "$DIR"/*/; do
        [ -d "$SUB" ] || continue
        FILE_COUNT=$(find "$SUB" -maxdepth 1 -type f | wc -l)
        DIRS+=("$SUB")
        printf "%d) %s (%d files)\n" "$i" "$(basename "$SUB")" "$FILE_COUNT"
        i=$((i+1))
    done
}

# Function: interactive selection
select_directory() {
    local CURRENT="$1"
    while true; do
        echo -e "\nAvailable directories under $CURRENT:"
        list_dirs "$CURRENT"
        # Flush output
        sleep 0.1

        echo -n "Enter the number of the directory you want to move: "
        read CHOICE

        if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#DIRS[@]}" ]; then
            SELECTED="${DIRS[$((CHOICE-1))]}"
            echo -e "\nYou've selected: $SELECTED"
            # Show 1-level contents of the selected directory
            echo "Contents of this directory (1 level deep):"
            for SUB in "$SELECTED"/*/; do
                [ -d "$SUB" ] || continue
                FILE_COUNT=$(find "$SUB" -maxdepth 1 -type f | wc -l)
                printf "  %s (%d files)\n" "$(basename "$SUB")" "$FILE_COUNT"
            done
            echo -n "Is this the directory you want to copy from? [y/N]: "
            read CONFIRM
            if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
                echo "$SELECTED"
                return
            else
                CURRENT="$SELECTED"
            fi
        else
            echo "Invalid selection. Try again."
        fi
    done
}

# --- Start Script ---
echo "Welcome! This script will move directories under $BASE_SRC."

# Interactive directory selection
SRC=$(select_directory "$BASE_SRC")
echo -e "\nDirectory confirmed: $SRC"

# Compute destination suggestion from full relative path
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

# Clean empty directories
find "$SRC" -type d -empty -delete

echo -e "\nMove complete and empty directories cleaned!"
