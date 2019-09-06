#!/bin/bash

#
#
#

: ${DEL:="$1"}

if [[ -z "$DEL" ]]; then
    echo "Usage: ./delsub.sh <subfolder>"
    exit 2
fi

if [[ ! -s "root.dat" ]]; then
    >&2 echo "delsub.sh must be executed from a folder containing root.dat"
    exit 3
fi

if [[ ! -e "$DEL" ]]; then
    >&2 echo "Warning: $DEL does not exist in the file system. Attempting removal from located duplicates anyway"
fi

echo "Duplicate: $DEL"

HASHES=$(mktemp)
T=$(mktemp)
for DUP in duplicates_count_*.dat; do
    echo "- Processing $DUP"
    if [[ ! -s "${DUP}.orig" ]]; then
        cp "${DUP}" "${DUP}.orig"
    fi
    echo "  - Locating all hashes for paths starting with $DEL"
    grep -F " $DEL" "$DUP" | grep -o "^[^ ]\+ " | sort -u > "$HASHES"
    echo "  - Removing all entries for $(wc -l < "$HASHES") located hashes"
    grep -v -F -f "$HASHES" "$DUP" > "$T"
    echo "  - Removing ${DEL} from the file system"
    rm -r "$DEL"
    mv "$T" "$DUP"
done
rm "$HASHES"

