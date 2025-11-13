#!/bin/bash

BASE_SRC="/mnt/tank/storage-share/Media"
BASE_DST="/mnt/tank/media"

echo "Welcome! This script will move directories under $BASE_SRC."

# --- List top-level directories (show all) ---
mapfile -t TOP_DIRS < <(find "$BASE_SRC" -mindepth 1 -maxdepth 1 -type d | sort)
if [ "${#TOP_DIRS[@]}" -eq 0 ]; then
    echo "No directories found under $BASE_SRC. Exiting."
    exit 1
fi

echo -e "\nAvailable top-level directories:"
for i in "${!TOP_DIRS[@]}"; do
    echo "$((i+1))) $(basename "${TOP_DIRS[$i]}")"
done

if [ "${#TOP_DIRS[@]}" -eq 1 ]; then
    TOP_DIR="${TOP_DIRS[0]}"
    echo "Only one top-level directory found. Automatically selecting: $(basename "$TOP_DIR")"
else
    echo -n "Enter the number of the top-level directory: "
    read NUM1
    if [[ "$NUM1" =~ ^[0-9]+$ ]] && [ "$NUM1" -ge 1 ] && [ "$NUM1" -le "${#TOP_DIRS[@]}" ]; then
        TOP_DIR="${TOP_DIRS[$((NUM1-1))]}"
    else
        echo "Invalid selection!"
        exit 1
    fi
fi

# --- List second-level directories (skip completely empty) ---
mapfile -t SUB_DIRS < <(find "$TOP_DIR" -mindepth 1 -maxdepth 1 -type d -exec bash -c '[ "$(ls -A "{}")" ] && echo "{}"' \;)
if [ "${#SUB_DIRS[@]}" -eq 0 ]; then
    SRC="$TOP_DIR"
elif [ "${#SUB_DIRS[@]}" -eq 1 ]; then
    SRC="${SUB_DIRS[0]}"
    echo "Only one subdirectory found under $(basename "$TOP_DIR"). Automatically selecting: $(basename "$SRC")"
else
    echo -e "\nAvailable subdirectories under $(basename "$TOP_DIR"):"
    for i in "${!SUB_DIRS[@]}"; do
        echo "$((i+1))) $(basename "${SUB_DIRS[$i]}")"
    done
    echo -n "Enter the number of the subdirectory: "
    read NUM2
    if [[ "$NUM2" =~ ^[0-9]+$ ]] && [ "$NUM2" -ge 1 ] && [ "$NUM2" -le "${#SUB_DIRS[@]}" ]; then
        SRC="${SUB_DIRS[$((NUM2-1))]}"
    else
        echo "Invalid selection!"
        exit 1
    fi
fi

echo -e "\nYou've selected: $SRC"

# --- Destination prompt ---
REL_PATH="${SRC#$BASE_SRC/}"
DST_SUGGEST=$(echo "$REL_PATH" | tr '[:upper:]' '[:lower:]')
echo -n "Enter destination folder name (default: $DST_SUGGEST, under $BASE_DST): "
read DST_SUB
DST_SUB=${DST_SUB:-$DST_SUGGEST}
DST="$BASE_DST/$DST_SUB"
mkdir -p "$DST"

echo -e "\nSource: $SRC"
echo "Destination: $DST"

# --- Dry run ---
echo -e "\nStarting dry run (filtered output)..."
rsync -aAXn --remove-source-files --info=progress2,stats2 --partial "$SRC/" "$DST/" \
    | grep -E 'sent|Number of files transferred|^./'

echo -e "\nDry run complete. Press Enter to start actual move..."
read

# --- Count directories and files ---
DIR_COUNT=$(find "$SRC" -type d | wc -l)
FILE_COUNT=$(find "$SRC" -type f | wc -l)

# --- Actual move ---
rsync -aAX --remove-source-files --info=progress2,stats2 --partial "$SRC/" "$DST/" \
    | grep -E 'sent|Number of files transferred|^./'

# --- Clean empty directories ---
find "$SRC" -type d -empty -delete

# --- Summary ---
echo -e "\nMove complete!"
echo "Summary:"
echo "  Source: $SRC"
echo "  Destination: $DST"
echo "  Directories moved: $DIR_COUNT"
echo "  Files moved: $FILE_COUNT"
