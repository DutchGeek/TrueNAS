#!/bin/bash

# Settings
LEVELS=2
TREE_DEPTH=2
REGEX="^./([^/]+/){0,$((LEVELS-1))}[^/]+|sent|Number of files transferred"
BASE_SRC="/mnt/tank/storage-share/Media"

# Function: print tree with indentation, colors, and highlight selected directory
print_tree() {
    local DIR="$1"
    local DEPTH="$2"
    local SELECTED="$3"
    local INDENT=""
    for ((i=1;i<DEPTH;i++)); do
        INDENT="$INDENT  "
    done

    mapfile -t SUBDIRS < <(find "$DIR" -mindepth 1 -maxdepth 1 -type d | sort)
    for SUB in "${SUBDIRS[@]}"; do
        if [ "$SUB" == "$SELECTED" ]; then
            # Highlight selected directory in green
            echo -e "${INDENT}\033[1;32m$(basename "$SUB")\033[0m"
        else
            # Other directories in blue
            echo -e "${INDENT}\033[1;34m$(basename "$SUB")\033[0m"
        fi
        if [ "$DEPTH" -lt "$TREE_DEPTH" ]; then
            print_tree "$SUB" $((DEPTH+1)) "$SELECTED"
        fi
    done
}

# Function: interactive drill-down with tree preview
select_directory() {
    local CURRENT_DIR="$1"
    while true; do
        mapfile -t DIRS < <(find "$CURRENT_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
        if [ ${#DIRS[@]} -eq 0 ]; then
            echo "No further subdirectories in $CURRENT_DIR"
            break
        fi

        COLUMNS=1
        echo "Subdirectories in $CURRENT_DIR:"
        select DIR in "${DIRS[@]}"; do
            if [ -n "$DIR" ]; then
                echo "Selected: $DIR"

                echo "Contents of $DIR (up to $TREE_DEPTH levels):"
                print_tree "$DIR" 1 "$DIR"

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

# Destination suggestion mirrors full relative path, lowercase
REL_PATH="${SRC#$BASE_SRC/}"
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
