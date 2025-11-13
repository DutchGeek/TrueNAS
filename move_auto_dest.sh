#!/bin/bash

# Settings
REGEX="^./([^/]+/){0,1}[^/]+|sent|Number of files transferred"
BASE_SRC="/mnt/tank/storage-share/Media"

# Function: print 1-level tree with file counts
print_tree_one_level() {
    local DIR="$1"
    mapfile -t SUBDIRS < <(find "$DIR" -mindepth 1 -maxdepth 1 -type d | sort)
    for SUB in "${SUBDIRS[@]}"; do
        FILE_COUNT=$(find "$SUB" -maxdepth 1 -type f | wc -l)
        printf "  \033[1;34m%s\033[0m (%d files)\n" "$(basename "$SUB")" "$FILE_COUNT"
    done
}

# Function: show directory options with preview before selection
select_directory() {
    local CURRENT_DIR="$1"
    while true; do
        mapfile -t DIRS < <(find "$CURRENT_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
        if [ ${#DIRS[@]} -eq 0 ]; then
            echo "No further subdirectories in $CURRENT_DIR"
            echo "$CURRENT_DIR"
            return
        fi

        echo -e "\nAvailable directories under $CURRENT_DIR:"
        for i in "${!DIRS[@]}"; do
            DIR="${DIRS[$i]}"
            FILE_COUNT=$(find "$DIR" -maxdepth 1 -type f | wc -l)
            printf "%d) \033[1;34m%s\033[0m (%d files)\n" "$((i+1))" "$(basename "$DIR")" "$FILE_COUNT"
        done

        echo
        read -p "Enter the number of the directory you want to move: " CHOICE

        if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#DIRS[@]}" ]; then
            DIR="${DIRS[$((CHOICE-1))]}"
            echo -e "\nYou've selected: $DIR"
            echo "Contents of this directory (1 level deep):"
            print_tree_one_level "$DIR"

            read -p "Is this the directory you want to copy from? [y/N]: " CONFIRM
            if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
                echo "Directory confirmed: $DIR"
                echo "$DIR"
                return
            else
                CURRENT_DIR="$DIR"
            fi
        else
            echo "Invalid selection. Try again."
        fi
    done
}

# --- Start Script ---
echo "Welcome! This script will move directories under $BASE_SRC."
echo "You will be prompted to select which directory to move."

SRC=$(select_directory "$BASE_SRC")

# Compute destination suggestion based on relative path from base
REL_PATH="${SRC#$BASE_SRC/}"   # strip the base path
DST_SUGGEST=$(echo "$REL_PATH" | tr '[:upper:]' '[:lower:]')
read -p "Enter destination folder name (default: $DST_SUGGEST, under /mnt/tank/media): " DST_SUB
DST_SUB=${DST_SUB:-$DST_SUGGEST}
DST="/mnt/tank/media/$DST_SUB"

# Ensure destination exists
mkdir -p "$DST"

# Show summary of source
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
