#!/bin/bash

PROPRIETARY="proprietary-files.txt"

function information {
    echo "sha1sum-files.sh:"
    echo ""
    echo "Uses git to process the manually added or modified"
    echo "blobs that are not extracted via extract-files.sh."
    echo ""
    echo "This is useful for devices that use another source"
    echo "for most of their blobs that are not the OEM ones."
    echo ""
    echo "Warning: Use [git add -A] to index the files before"
    echo "running this script."
    echo ""
    echo "Usage:"
    echo ""
    echo "./sha1sum-files.sh --added"
    echo "   This will pin all the new files in the git index."
    echo ""
    echo "./sha1sum-files.sh --modified"
    echo "   This will update the SHA for the modified files."
    echo ""
    echo "./sha1sum-files.sh --renamed"
    echo "   This will pin the modified files if you have"
    echo "   moved or renamed them."
    echo ""
    echo "./sha1sum-files.sh --help"
    echo "   Shows this information just for you."
    echo ""
    echo "Disclaimer: This script is copyleft, take whatwever you need."
}

while [ "$1" != "" ]; do
    case $1 in
        -a | --added )       filter="A --cached"
                             MODE="ADD"
                             ;;
        -m | --modified )    filter="M --cached"
                             MODE="MOD"
                             ;;
        -r | --renamed )     filter="R --cached"
                             MODE="REN"
                             ;;
        -h | --help )        HELP="yes"
                             ;;
    esac
    shift
done

if [ ! -z $HELP ]; then
    information
    exit 1
fi

if [ -z "$filter" ]; then
    echo "Something went wrong, try running:"
    echo "./sha1sum-files.sh -h"
    exit 0
fi

# For renamed files, we need to remove the deprecated lines
# after it was renamed.
if [ $MODE = "REN" ]; then
    BREN=$(git diff -M --cached --name-status | awk '{print $2}')
    for BRENN in $BREN; do
        BNAME=$(echo $BRENN | sed 's/proprietary//' | sed 's/^[-\/]*//')
        NUM=$(grep -n "$BNAME" $PROPRIETARY | sed 's/^\([0-9]\+\):.*$/\1/')
        sed -i "${NUM}d" $PROPRIETARY
    done
fi;

# Query every changed file accounting to the respective filter.
FILES=$(git diff --name-only --diff-filter=$filter)
for FILE in $FILES; do
    SHA=$(sha1sum $FILE | awk '{print $1}')
    NAME=$(echo $FILE | sed 's/proprietary//' | sed 's/^[-\/]*//')
    # Just add the new files.
    if [ $MODE = "ADD" ] || [ $MODE = "REN" ]; then
        echo "$NAME|$SHA" >> $PROPRIETARY
    elif [ $MODE = "MOD" ]; then
        PINNED=$(cat $PROPRIETARY | grep $NAME | grep "|")
        if [ -z $PINNED ]; then
            # Pin the new modified file by appeding the new SHA.
            STRING=$(cat $PROPRIETARY | grep $NAME)
            sed -i -e "s#\b$STRING\b#&|$SHA#" $PROPRIETARY
        else
            # Just replace the old unique SHA with the new one.
            OLD=$(echo $PINNED | sed 's/.*[|]//')
            NEW=$SHA
            sed -i -e "s/$OLD/$NEW/g" $PROPRIETARY
        fi;
    fi;
done

# Organize the blobs file list with 'sort'.
cat $PROPRIETARY | sort -u > temporary.txt
mv temporary.txt $PROPRIETARY
