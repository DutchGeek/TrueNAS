#!/bin/bash

BASE_SRC="/mnt/tank/storage-share/Media"

# Function to list directories 1 level deep
list_dirs() {
    local DIR="$1"
    mapfile -t DIRS < <(find "$DIR" -mindepth 1 -maxdepth 1 -type d | sort)
    for i in "${!DIRS[@]}"; do
        FILE_COUNT=$(find "${DIRS[$i]}" -maxdepth 1 -type f | wc -l)
        printf "%d) %s (%d files)\n" "$((i+1))" "$(basename "${DIRS[$i]}")" "$FILE_COUNT"
    done
}

# Function to select directory
select_directory() {
    local CURRENT="$1"
    while true; do
        echo -e "\nAvailable directories under $CURRENT:"
        list_dirs "$CURRENT"

        echo
        read -p "Enter the number of the directory you want to move: " CHOICE
        mapfile -t DIRS < <(find "$CURRENT" -mindepth 1 -maxdepth 1 -type d | sort)

        if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#DIRS[@]}" ]; then
            SELECTED="${DIRS[$((CHOICE-1))]}"
            echo -e "\nYou've selected: $SELECTED"
            return 0
        else
            echo "Invalid selection. Try again."
        fi
    done
}

echo "Welcome! This script will move directories under $BASE_SRC."

select_directory "$BASE_SRC"
SRC="$SELECTED"

echo "Directory confirmed: $SRC"
REL_PATH="${SRC#$BASE_SRC/}"
DST_SUGGEST=$(echo "$REL_PATH" | tr '[:upper:]' '[:lower:]')
read -p "Enter destination folder name (default: $DST_SUGGEST, under /mnt/tank/media): " DST_SUB
DST_SUB=${DST_SUB:-$DST_SUGGEST}
DST="/mnt/tank/media/$DST_SUB"

echo "Source: $SRC"
echo "Destination: $DST"
