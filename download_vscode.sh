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

# Determine the architecture so we can skip the code-server binary that does
# not match this platform. The MANIFEST lists both amd64 and arm64.
case $(uname -m) in
    arm64|aarch64) ARCH=arm64; OTHER_ARCH=amd64 ;;
    *)             ARCH=amd64; OTHER_ARCH=arm64 ;;
esac

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
            # Skip the code-server binary for the other architecture.
            if [[ "$line" == *"$OTHER_ARCH"* ]]; then
                echo "${line##*/} (skipping: not $ARCH)"
                skip=1
                continue
            fi
            url=$line
            fname=${url##*/}
            fpath=downloads/$fname
            echo "$fname"
        else
            echo "- ERROR: sha256 not supplied"
            exit -1
        fi
        continue
    elif [ -n "$skip" ]; then
        # Consume the checksum line belonging to the skipped URL.
        skip=
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
