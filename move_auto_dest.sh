#!/bin/bash

BASE_SRC="/mnt/tank/storage-share/Media"
BASE_DST="/mnt/tank/media"

echo "Welcome! This script will move directories under $BASE_SRC."

# List non-empty subdirectories 1 level deep and number them
list_dirs() {
    local DIR="$1"
    DIRS=()
    local i=1
    for SUB in "$DIR"/*/; do
        [ -d "$SUB" ] || continue
        # Count files to skip empty dirs
        FILE_COUNT=$(find "$SUB" -maxdepth 1 -type f | wc -l)
        [ "$FILE_COUNT" -eq 0 ] && continue
        DIRS+=("${SUB%/}")
        echo "$i) $(basename "${SUB%/}")"
        i=$((i+1))
    done
}

# --- Select top-level directory ---
echo -e "\nAvailable top-level directories:"
list_dirs "$BASE_SRC"

echo -n "Enter the number of the top-level directory: "
read NUM1
if [[ "$NUM1" =~ ^[0-9]+$ ]] && [ "$NUM1" -ge 1 ] && [ "$NUM1" -le "${#DIRS[@]}" ]; then
    TOP_DIR="${DIRS[$((NUM1-1))]}"
else
    echo "Invalid selection!"
    exit 1
fi

# --- Select second-level directory (auto if only one non-empty) ---
list_dirs "$TOP_DIR"

if [ "${#DIRS[@]}" -eq 0 ]; then
    SRC="$TOP_DIR"
elif [ "${#DIRS[@]}" -eq 1 ]; then
    SRC="${DIRS[0]}"
    echo -e "\nOnly one non-empty subdirectory found under $TOP_DIR."
    echo "Automatically selecting: $SRC"
else
    echo -e "\nAvailable subdirectories under $TOP_DIR:"
    for i in "${!DIRS[@]}"; do
        echo "$((i+1))) $(basename "${DIRS[$i]}")"
    done
    echo -n "Enter the number of the subdirectory: "
    read NUM2
    if [[ "$NUM2" =~ ^[0-9]+$ ]] && [ "$NUM2" -ge 1 ] && [ "$NUM2" -le "${#DIRS[@]}" ]; then
        SRC="${DIRS[$((NUM2-1))]}"
    else
        echo "Invalid selection!"
        exit 1
    fi
fi

echo -e "\nYou've selected: $SRC"

# Destination prompt with default suggestion
REL_PATH="${SRC#$BASE_SRC/}"
DST_SUGGEST=$(echo "$REL_PATH" | tr '[:upper:]' '[:lower:]')
echo -n "Enter destination folder name (default: $DST_SUGGEST, under $BASE_DST): "
read DST_SUB
DST_SUB=${DST_SUB:-$DST_SUGGEST}
DST="$BASE_DST/$DST_SUB"

mkdir -p "$DST"

echo -e "\nSource: $SRC"
echo "Destination: $DST"

# Dry run with filtered output
echo -e "\nStarting dry run (filtered output)..."
rsync -aAXn --remove-source-files --info=progress2,stats2 --partial "$SRC/" "$DST/" \
    | grep -E 'sent|Number of files transferred|^./'

echo -e "\nDry run complete. Press Enter to start actual move..."
read

# Count directories and files before move
DIR_COUNT=$(find "$SRC" -type d | wc -l)
FILE_COUNT=$(find "$SRC" -type f | wc -l)

# Actual move with filtered output
rsync -aAX --remove-source-files --info=progress2,stats2 --partial "$SRC/" "$DST/" \
    | grep -E 'sent|Number of files transferred|^./'

# Clean empty directories
find "$SRC" -type d -empty -delete

# Summary
echo -e "\nMove complete!"
echo "Summary:"
echo "  Source: $SRC"
echo "  Destination: $DST"
echo "  Directories moved: $DIR_COUNT"
echo "  Files moved: $FILE_COUNT"
