#!/bin/bash

BASE_SRC="/mnt/tank/storage-share/Media"

# Function to list directories 1 level deep and select
select_directory() {
    local CURRENT="$1"
    while true; do
        echo -e "\nAvailable directories under $CURRENT:"
        i=1
        DIRS=()
        for DIR in "$CURRENT"/*/; do
            [ -d "$DIR" ] || continue
            FILE_COUNT=$(find "$DIR" -maxdepth 1 -type f | wc -l)
            DIRS+=("$DIR")
            printf "%d) %s (%d files)\n" "$i" "$(basename "$DIR")" "$FILE_COUNT"
            i=$((i+1))
        done

        if [ ${#DIRS[@]} -eq 0 ]; then
            echo "No subdirectories found under $CURRENT"
            echo "$CURRENT"
            return
        fi

        echo
        read -p "Enter the number of the directory you want to move: " CHOICE
        if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#DIRS[@]}" ]; then
            SELECTED="${DIRS[$((CHOICE-1))]}"
            echo -e "\nYou've selected: $SELECTED"
            echo "$SELECTED"
            return
        else
            echo "Invalid selection. Try again."
        fi
    done
}

echo "Welcome! This script will move directories under $BASE_SRC."

SRC=$(select_directory "$BASE_SRC")
echo "Directory confirmed: $SRC"

REL_PATH="${SRC#$BASE_SRC/}"
DST_SUGGEST=$(echo "$REL_PATH" | tr '[:upper:]' '[:lower:]')
read -p "Enter destination folder name (default: $DST_SUGGEST, under /mnt/tank/media): " DST_SUB
DST_SUB=${DST_SUB:-$DST_SUGGEST}
DST="/mnt/tank/media/$DST_SUB"

echo "Source: $SRC"
echo "Destination: $DST"
