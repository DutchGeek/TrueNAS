#!/bin/bash

BASE_SRC="/mnt/tank/storage-share/Media"

# List directories 1 level deep, numbered
list_dirs() {
    local DIR="$1"
    DIRS=()
    local i=1
    for SUB in "$DIR"/*/; do
        [ -d "$SUB" ] || continue
        DIRS+=("${SUB%/}")
        echo "$i) $(basename "${SUB%/}")"
        i=$((i+1))
    done
}

# Interactive selection
select_directory() {
    local CURRENT="$1"
    while true; do
        echo -e "\nAvailable directories under $CURRENT:"
        list_dirs "$CURRENT"
        echo -n "Enter the number of the directory you want to move: "
        read CHOICE

        if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#DIRS[@]}" ]; then
            SELECTED="${DIRS[$((CHOICE-1))]}"
            echo -e "\nYou've selected: $SELECTED"

            # Show 1-level contents
            echo "Contents of this directory (1 level deep):"
            for SUB in "$SELECTED"/*/; do
                [ -d "$SUB" ] || continue
                FILE_COUNT=$(find "$SUB" -maxdepth 1 -type f | wc -l)
                echo "  $(basename "${SUB%/}") ($FILE_COUNT files)"
            done

            echo -n "Is this the directory you want to copy from? [y/N]: "
            read CONFIRM
            if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
                echo "$SELECTED"
                return
            else
                echo "Returning to parent directory selection..."
            fi
        else
            echo "Invalid selection. Try again."
        fi
    done
}

# --- Script Start ---
echo "Welcome! This script will move directories under $BASE_SRC."

SRC=$(select_directory "$BASE_SRC")
echo -e "\nDirectory confirmed: $SRC"

REL_PATH="${SRC#$BASE_SRC/}"
DST_SUGGEST=$(echo "$REL_PATH" | tr '[:upper:]' '[:lower:]')
echo -n "Enter destination folder name (default: $DST_SUGGEST, under /mnt/tank/media): "
read DST_SUB
DST_SUB=${DST_SUB:-$DST_SUGGEST}
DST="/mnt/tank/media/$DST_SUB"

mkdir -p "$DST"

echo -e "\nSource: $SRC"
echo "Destination: $DST"

echo -e "\nStarting dry run..."
rsync -aAXn --remove-source-files --info=progress2,stats2 --partial "$SRC/" "$DST/"

echo -e "\nDry run complete. Press Enter to start actual move..."
read

rsync -aAX --remove-source-files --info=progress2,stats2 --partial "$SRC/" "$DST/"

echo -e "\nCleaning empty directories..."
find "$SRC" -type d -empty -delete

echo -e "\nMove complete!"
