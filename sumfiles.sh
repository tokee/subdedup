#!/bin/bash

#
# Calculates checksums for files under a given root
#

: ${ROOT_FOLDER:="$1"}
: ${DEST:="sums_files_$(sed 's/[\/ ]/_/g' <<< "$ROOT_FOLDER").dat"}

echo " - Calculating md5 checksums for all files under '$ROOT_FOLDER', storing in $DEST"
find "$ROOT_FOLDER" -type f -exec md5sum {} \; > "$DEST"
