#!/bin/bash

#
# Calculates folder checksums from file checksums
#

: ${FILE_CHECKSUMS:="$1"}
: ${DEST:="sums_folders.dat"}

get_folder_regexp() {
    local D="$1"
    REGEXP=""
    while [[ "$D" -gt 0 ]]; do
        REGEXP="${REGEXP}[^/]*/"
        D=$(( D-1 ))
    done
    REGEXP="${REGEXP}[^/]*$"
    echo -n "$REGEXP"
}

get_all_regexp() {
    local D="$1"
    REGEXP=""
    while [[ "$D" -gt 0 ]]; do
        REGEXP="${REGEXP}[^/]*/"
        D=$(( D-1 ))
    done
    REGEXP="${REGEXP}[^/]*[/]\?$"
    echo -n "$REGEXP"
}

create_raw_folders() {
    if [[ -s t_raw_folders.dat ]]; then
        echo " - Skipping raw folder extraction as t_raw_folders.dat already exists"
    else
        echo " - Extracting raw folders"
        sed -e 's/^[^ ]*  //' -e 's/\/[^\/]\+$/\//' < "$FILE_CHECKSUMS" | LC_ALL=C sort -u > t_raw_folders.dat
    fi
}

create_folder_checksums() {
    if [[ -s "t_all_checksums.dat" ]]; then
        echo " - Skipping folder checksum calculation as t_all_checksums.dat exists"
        return
    fi
    cp "$FILE_CHECKSUMS" "t_all_checksums_work.dat"
    echo -n "" > t_folder_checksums.dat
    DEPTH=$MAX_DEPTH
    while [[ "$DEPTH" -gt 0 ]]; do
        echo " - Calculating folder checksums for depth $DEPTH"

        # Get folders
        FOLDER_REGEXP="^$(get_folder_regexp $DEPTH)"
        echo "   - Extracting folders"
        grep "$FOLDER_REGEXP" "t_raw_folders.dat" | LC_ALL=C sort -u > t_raw_folders_depth_${DEPTH}.dat
        
        ALL_REGEXP="^$(get_all_regexp $DEPTH)"
        echo "   - Calculating checksums for $(wc -l < t_raw_folders_depth_${DEPTH}.dat) folders"
        echo -n "" > t_sum_folders_depth_${DEPTH}.dat
        while read -r FOLDER; do
            #        echo "Folder: $FOLDER"
            #        grep -F "$FOLDER" "t_all_checksums_work.dat" | grep "$ALL_REGEXP"
            MD5=$(md5sum <<< $(grep -F "$FOLDER" "t_all_checksums_work.dat" | grep "$ALL_REGEXP" | sed 's/^\([^ ]*\)  .*/\1/') | sed 's/  -//')
            #        echo "*** $MD5  $FOLDER"
            echo "$MD5  $FOLDER" >> t_sum_folders_depth_${DEPTH}.dat
        done < t_raw_folders_depth_${DEPTH}.dat
        cat t_sum_folders_depth_${DEPTH}.dat >> "t_folder_checksums.dat"
        cat t_sum_folders_depth_${DEPTH}.dat >> "t_all_checksums_work.dat"
        rm t_raw_folders_depth_${DEPTH}.dat t_sum_folders_depth_${DEPTH}.dat
        
        DEPTH=$(( DEPTH-1))
    done
    LC_ALL=C sort < t_all_checksums_work.dat > t_all_checksums.dat
}

create_duplicate_checksums() {
    if [[ -s "t_all_duplicate_checksums.dat" ]]; then
        echo " - Skipping base duplicate search as t_all_duplicate_checksums.dat already exists"
    else
        echo " - Performing base duplicate search"
        sed 's/^\([^ ]*\)  .*/\1/' t_all_checksums.dat | LC_ALL=C sort | uniq -c | grep -v " *1 " | sed 's/ *[0-9]* //' | LC_ALL=C sort > "t_all_duplicate_checksums.dat"
    fi
    if [[ -s "t_all_duplicates.dat" ]]; then
        echo " - Skipping creation of  _tall_duplicates.dat as it already exists"
    else
        echo " - Generating t_all_duplicates.dat"
        LC_ALL=C join t_all_duplicate_checksums.dat t_all_checksums.dat | sed 's/\([^ ]*\) /\1  /' > "t_all_duplicates.dat"
    fi
}


echo "Calculating md5 checksums for all folders from the files checksum '$FILE_CHECKSUMS'"
create_raw_folders

echo " - Calculating max folder depth"
MAX_DEPTH=$(( $(sed 's/[^\/]//g' < t_folders.dat | sort -ur | head -n 1 | wc -c)-1 ))

create_folder_checksums
create_duplicate_checksums
