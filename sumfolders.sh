#!/bin/bash

#
# Calculates folder checksums from file checksums
#

: ${FILE_CHECKSUMS:="$1"}
: ${DEST:="sums_folders.dat"}

echo "Calculating md5 checksums for all folders from the files checksum '$FILE_CHECKSUMS'"

echo " - Extracting unique folders"
sed -e 's/^[^ ]*  //' -e 's/\/[^\/]\+$/\//' < "$FILE_CHECKSUMS" | LC_ALL=C sort -u > t_folders.dat
echo " - Calculating max folder depth"
DEPTH=$(( $(sed 's/[^\/]//g' < t_folders.dat | sort -ur | head -n 1 | wc -c)-1 ))

cp "$FILE_CHECKSUMS" > "t_all_checksums.dat"
while [[ "$DEPTH" -gt 0 ]]; do
    echo " - Calculating folder checksums for depth $DEPTH"
    REGEXP="  "
    D=$DEPTH
    while [[ "$D" -gt 0 ]]; do
        REGEXP="${REGEXP}[^/]*/"
        D=$(( D-1 ))
    done
    REGEXP="${REGEXP}[^/]*$"
    
    echo "   - Regexp: $REGEXP"
    grep "$REGEXP" "t_folders.dat" >
    DEPTH=$(( DEPTH-1))
done
