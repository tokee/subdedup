#!/bin/bash

#
# Calculates folder checksums from file checksums
#

: ${ROOT_FOLDER:="$1"}
: ${F:="sums_files_$(sed 's/[\/ ]/_/g' <<< "$ROOT_FOLDER")"}
: ${FILE_CHECKSUMS:="${F}/file_checksums.dat"}
: ${MIN_COUNT:="$2"}
: ${MIN_COUNT:="2"} # 2+ = folders only, 1 = everything (including files)
: ${DEST:="sums_folders.dat"}

mkdir -p "$F"

file_checksums() {
    if [[ -s "$FILE_CHECKSUMS" ]]; then
        echo " - Skipping file checksum calculation as $FILE_CHECKSUMS already exists"
    else
        echo " - Calculating md5 checksums for all files under '$ROOT_FOLDER', storing in $FILE_CHECKSUMS"
        find "$ROOT_FOLDER" -type f -exec md5sum {} \; > "$FILE_CHECKSUMS"
    fi
}

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
    if [[ -s ${F}/raw_folders.dat ]]; then
        echo " - Skipping raw folder extraction as ${F}/raw_folders.dat already exists"
    else
        echo " - Extracting raw folders"
        sed -e 's/^[^ ]*  //' -e 's/\/[^\/]\+$/\//' < "$FILE_CHECKSUMS" | LC_ALL=C sort -u > ${F}/raw_folders.dat
    fi
}

create_folder_checksums() {
    if [[ -s "${F}/all_checksums.dat" ]]; then
        echo " - Skipping folder checksum calculation as ${F}/all_checksums.dat exists"
        return
    fi
    echo -n " - Calculating max folder depth... "
    MAX_DEPTH=$(( $(sed 's/[^\/]//g' < ${F}/raw_folders.dat | sort -ur | head -n 1 | wc -c)-1 ))
    echo "$MAX_DEPTH"
    
    sed 's/^\(.*\)\+  /\1 1  /' < "$FILE_CHECKSUMS" > "${F}/all_checksums_work.dat"
    echo -n "" > ${F}/folder_checksums.dat
    DEPTH=$MAX_DEPTH
    while [[ "$DEPTH" -gt 0 ]]; do
        echo " - Calculating folder checksums for depth $DEPTH"

        # Get folders
        FOLDER_REGEXP="^$(get_folder_regexp $DEPTH)"
        echo "   - Extracting folders"
        grep "$FOLDER_REGEXP" "${F}/raw_folders.dat" | LC_ALL=C sort -u > ${F}/raw_folders_depth_${DEPTH}.dat
        
        ALL_REGEXP="^$(get_all_regexp $DEPTH)"
        echo "   - Calculating checksums for $(wc -l < ${F}/raw_folders_depth_${DEPTH}.dat) folders"
        echo -n "" > ${F}/sum_folders_depth_${DEPTH}.dat
        while read -r FOLDER; do
#            if [[ "." == .$(grep mus20160209 <<< "$FOLDER") ]]; then
#                continue
#            fi
#            echo "Folder: $FOLDER"
            #        grep -F "$FOLDER" "${F}/all_checksums_work.dat" | grep "$ALL_REGEXP"
#            grep -F "$FOLDER" "${F}/all_checksums_work.dat" | grep "$ALL_REGEXP" | sed 's/^\([^ ]*\) .*/\1/'
            MD5=$(md5sum <<< $(grep -F "$FOLDER" "${F}/all_checksums_work.dat" | grep "$ALL_REGEXP" | sed 's/^\([^ ]*\) .*/\1/') | sed 's/  -//')
            COUNT=$( bc <<< "$(grep -F "$FOLDER" "${F}/all_checksums_work.dat" | grep "$ALL_REGEXP" | sed 's/^[^ ]* \([0-9]\+\) .*/\1/' | tr '\n' '+')0")
 #                   echo "*** $MD5  $FOLDER"
            echo "$MD5 $COUNT  $FOLDER" >> ${F}/sum_folders_depth_${DEPTH}.dat
        done < ${F}/raw_folders_depth_${DEPTH}.dat
        cat ${F}/sum_folders_depth_${DEPTH}.dat >> "${F}/folder_checksums.dat"
        cat ${F}/sum_folders_depth_${DEPTH}.dat >> "${F}/all_checksums_work.dat"
        rm ${F}/raw_folders_depth_${DEPTH}.dat ${F}/sum_folders_depth_${DEPTH}.dat
        
        DEPTH=$(( DEPTH-1))
    done
    LC_ALL=C sort < ${F}/all_checksums_work.dat > ${F}/all_checksums.dat
}

create_duplicate_checksums() {
    if [[ -s "${F}/all_duplicate_checksums.dat" ]]; then
        echo " - Skipping base duplicate search as ${F}/all_duplicate_checksums.dat already exists"
    else
        echo " - Performing base duplicate search"
        sed 's/^\([^ ]*\) .*/\1/' ${F}/all_checksums.dat | LC_ALL=C sort | uniq -c | grep -v " *1 " | sed 's/ *[0-9]* //' | LC_ALL=C sort > "${F}/all_duplicate_checksums.dat"
    fi
    if [[ -s "${F}/all_duplicates.dat" ]]; then
        echo " - Skipping creation of ${F}/all_duplicates.dat as it already exists"
    else
        echo " - Generating ${F}/all_duplicates.dat"
        LC_ALL=C join ${F}/all_duplicate_checksums.dat ${F}/all_checksums.dat | sed 's/\([^ ]*\) /\1  /' > "${F}/all_duplicates.dat"
    fi
}

print_duplicates() {
    local IN="$1"

    cp "$IN" ${F}/work.dat
    while [[ -s ${F}/work.dat ]]; do
        local HASH=$(head -n 1 ${F}/work.dat | cut -d\  -f1)
        local COUNT=$(head -n 1 ${F}/work.dat | cut -d\  -f3)
        if [[ "$COUNT" -lt "$MIN_COUNT" ]]; then
            return
        fi
        grep "^$HASH" ${F}/work.dat
        grep -v "^$HASH" ${F}/work.dat > ${F}/left.dat
        echo ""
        mv ${F}/left.dat ${F}/work.dat
    done
    rm ${F}/work.dat
}

duplicates_count() {
    if [[ -s "${F}/all_duplicates_count_${MIN_COUNT}.dat" ]]; then
        echo " - Skipping creation of duplicates_count_${MIN_COUNT}.dat as it already exists"
        return
    fi

    echo " - Creating duplicates_count_${MIN_COUNT}.dat"
    if [[ -s "${F}/all_duplicates_sorted_count.dat" ]]; then
        echo "   - Skipping creation of ${F}/all_duplicates_sorted_count.dat as it already exists"
    else
        echo "   - Creating ${F}/all_duplicates_sorted_count.dat"
        LC_ALL=C sort -k2,2nbr -k1,1b ${F}/all_duplicates.dat > ${F}/all_duplicates_sorted_count.dat
    fi
    echo "   - Extracting duplicates with MIN_COUNT==${MIN_COUNT}"
    print_duplicates "${F}/all_duplicates_sorted_count.dat" > ${F}/duplicates_count_${MIN_COUNT}.dat

#    echo " - Creating duplicates_size.dat"
#    LC_ALL=C sort -k2,2nbr -k1,1b ${F}/all_duplicates.dat > ${F}/all_duplicates_sorted_count.dat
#    print_duplicates "${F}/all_duplicates_sorted_count.dat" > duplicates_count.dat
}

START_TIME=$(date +%s)
file_checksums
create_raw_folders
create_folder_checksums
create_duplicate_checksums
duplicates_count
END_TIME=$(date +%s)
TOTAL_TIME=$(( END_TIME-START_TIME ))
echo "Finished in ${TOTAL_TIME} seconds. Result available in ${F}/duplicates_count_${MIN_COUNT}.dat"
