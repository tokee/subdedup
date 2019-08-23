#!/bin/bash

#
# Calculates folder checksums from file checksums
#

: ${FILE_CHECKSUMS:="$1"}
: ${MIN_COUNT:="$2"}
: ${MIN_COUNT:="2"} # 2+ = folders only, 1 = everything (including files)
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
    echo -n " - Calculating max folder depth... "
    MAX_DEPTH=$(( $(sed 's/[^\/]//g' < t_raw_folders.dat | sort -ur | head -n 1 | wc -c)-1 ))
    echo "$MAX_DEPTH"
    
    sed 's/^\(.*\)\+  /\1 1  /' < "$FILE_CHECKSUMS" > "t_all_checksums_work.dat"
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
#            if [[ "." == .$(grep mus20160209 <<< "$FOLDER") ]]; then
#                continue
#            fi
#            echo "Folder: $FOLDER"
            #        grep -F "$FOLDER" "t_all_checksums_work.dat" | grep "$ALL_REGEXP"
#            grep -F "$FOLDER" "t_all_checksums_work.dat" | grep "$ALL_REGEXP" | sed 's/^\([^ ]*\) .*/\1/'
            MD5=$(md5sum <<< $(grep -F "$FOLDER" "t_all_checksums_work.dat" | grep "$ALL_REGEXP" | sed 's/^\([^ ]*\) .*/\1/') | sed 's/  -//')
            COUNT=$( bc <<< "$(grep -F "$FOLDER" "t_all_checksums_work.dat" | grep "$ALL_REGEXP" | sed 's/^[^ ]* \([0-9]\+\) .*/\1/' | tr '\n' '+')0")
 #                   echo "*** $MD5  $FOLDER"
            echo "$MD5 $COUNT  $FOLDER" >> t_sum_folders_depth_${DEPTH}.dat
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
        sed 's/^\([^ ]*\) .*/\1/' t_all_checksums.dat | LC_ALL=C sort | uniq -c | grep -v " *1 " | sed 's/ *[0-9]* //' | LC_ALL=C sort > "t_all_duplicate_checksums.dat"
    fi
    if [[ -s "t_all_duplicates.dat" ]]; then
        echo " - Skipping creation of  t_all_duplicates.dat as it already exists"
    else
        echo " - Generating t_all_duplicates.dat"
        LC_ALL=C join t_all_duplicate_checksums.dat t_all_checksums.dat | sed 's/\([^ ]*\) /\1  /' > "t_all_duplicates.dat"
    fi
}

print_duplicates() {
    local IN="$1"

    cp "$IN" t_work.dat
    while [[ -s t_work.dat ]]; do
        local HASH=$(head -n 1 t_work.dat | cut -d\  -f1)
        local COUNT=$(head -n 1 t_work.dat | cut -d\  -f3)
        if [[ "$COUNT" -lt "$MIN_COUNT" ]]; then
            return
        fi
        grep "^$HASH" t_work.dat
        grep -v "^$HASH" t_work.dat > t_left.dat
        echo ""
        mv t_left.dat t_work.dat
    done
    rm t_work.dat
}

duplicates_count() {
    echo " - Creating duplicates_count.dat"
    LC_ALL=C sort -k2,2nbr -k1,1b t_all_duplicates.dat > t_all_duplicates_sorted_count.dat
    print_duplicates "t_all_duplicates_sorted_count.dat" > duplicates_count.dat

#    echo " - Creating duplicates_size.dat"
#    LC_ALL=C sort -k2,2nbr -k1,1b t_all_duplicates.dat > t_all_duplicates_sorted_count.dat
#    print_duplicates "t_all_duplicates_sorted_count.dat" > duplicates_count.dat
}


create_raw_folders
create_folder_checksums
create_duplicate_checksums
duplicates_count
