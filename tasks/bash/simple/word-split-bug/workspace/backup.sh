#!/usr/bin/env bash
# Copy the flat contents of one directory into another.

usage() {
    echo "usage: backup.sh SRC DEST" >&2
}

if [ $# != 2 ]; then
    usage
    exit 2
fi

SRC=$1
DEST=$2

if [ ! -d $SRC ]; then
    echo "no such directory: $SRC" >&2
    exit 1
fi

mkdir -p $DEST

count=0
for f in $(ls $SRC); do
    if [ -f $SRC/$f ]; then
        cp $SRC/$f $DEST/$f
        count=`expr $count + 1`
    fi
done

echo "copied: $count"
