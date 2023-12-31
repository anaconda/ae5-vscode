#!/bin/bash

echo "+-----------------------+"
echo "| AE5 VSCode Downloader |"
echo "+-----------------------+"

TOOL_HOME=$(dirname "${BASH_SOURCE[0]}")

if [ $(uname) = Darwin ]; then
    SHA="shasum -a 256"
else
    SHA=sha256sum
fi

if [ ! -f MANIFEST ]; then
    echo "ERROR: file MANIFEST not found"
    exit -1
fi

if ! mkdir -p downloads; then
    echo "- ERROR: could not create the data directory"
    exit -1
fi

url=
while read -r line; do
    line=$(echo $line | sed -E 's@^ *(#.*)?@@;s@ *$@@')
    [ "$line" ] || continue
    if [[ "$line" == *"/"* ]]; then
        if [ -z "$url" ]; then
            url=$line
            fname=${url##*/}
            fpath=downloads/$fname
            echo "$fname"
        else
            echo "- ERROR: sha256 not supplied"
            exit -1
        fi
        continue
    elif [ -z "$url" ]; then
        echo "ERROR: unexpected data: $line"
        exit -1
    fi
    sha=$line
    if [ -f $fpath ]; then
        echo -n "  checksum: "
        actual_sha=$($SHA $fpath | cut -d ' ' -f 1)
        echo "$actual_sha"
        if [ "$actual_sha" == "$sha" ]; then
            echo "  verified; skipping download"
            url=
            continue
        fi
        echo "  mismatch: $sha; repeating download"
    fi
    echo "  downloading: $url"
    if ! curl --stderr - -o $fpath -L "$url" | sed -E 's@^@  | @;s@\r@\r  | @g'; then
        echo "  ERROR: could not complete download"
        exit -1
    fi
    url=
    echo -n "  checksum: "
    actual_sha=$($SHA $fpath | cut -d ' ' -f 1)
    echo " $actual_sha"
    if [ "$actual_sha" != "$sha" ]; then
        echo " mismatch: $sha; please check manifest"
        exit -1
    fi
done < MANIFEST
