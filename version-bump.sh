#!/bin/bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: version-bump.sh

Rewrite MANIFEST in place with the latest upstream version of each
section that has # check: / # match: comments, including checksums.
Sections without those comments are left alone. Open-VSX JSON with
preRelease:true is not bumped.
EOF
}

for arg in "$@"; do
    case "$arg" in
        -h|--help) usage; exit 0 ;;
        *)
            echo "Unknown argument: $arg" >&2
            usage >&2
            exit 1
            ;;
    esac
done

cd "$(dirname "${BASH_SOURCE[0]}")"

version_le() {
    local IFS='.'
    local a=($1) b=($2)
    local i ai bi n
    n=${#a[@]}
    if [ ${#b[@]} -gt "$n" ]; then
        n=${#b[@]}
    fi
    i=0
    while [ "$i" -lt "$n" ]; do
        ai=${a[$i]:-0}
        bi=${b[$i]:-0}
        if ((10#$ai < 10#$bi)); then return 0; fi
        if ((10#$ai > 10#$bi)); then return 1; fi
        i=$((i + 1))
    done
    return 0
}

file_sha256() {
    if [ "$(uname)" = Darwin ]; then
        shasum -a 256 "$1" | cut -d ' ' -f 1
    else
        sha256sum "$1" | cut -d ' ' -f 1
    fi
}

ensure_hashed() {
    local url=$1
    local fname=${url##*/}
    local fpath=downloads/$fname
    mkdir -p downloads
    if [ ! -f "$fpath" ]; then
        echo "  downloading: $url" >&2
        curl -fL --retry 3 -o "$fpath" "$url"
    else
        echo "  using existing: $fpath" >&2
    fi
    file_sha256 "$fpath"
}

max_match_version() {
    local match=$1
    local body=$2
    local tmp m ver max=
    tmp=$(mktemp)
    printf '%s\n' "$body" | grep -oE "$match" > "$tmp" || true
    while IFS= read -r m || [ -n "${m:-}" ]; do
        [ -n "${m:-}" ] || continue
        if [[ $m =~ $match ]]; then
            ver="${BASH_REMATCH[1]}"
            if [ -z "$max" ] || ! version_le "$ver" "$max"; then
                max=$ver
            fi
        fi
    done < "$tmp"
    rm -f "$tmp"
    printf '%s' "$max"
}

fetch_body() {
    local url=$1
    case "$url" in
        https://airgap.svc.anaconda.com/\?*)
            url="https://airgap-svc.s3.us-east-1.amazonaws.com/?${url#*\?}"
            ;;
    esac
    curl -fsSL -A 'ae5-vscode-version-bump' "$url"
}

is_prerelease() {
    printf '%s\n' "$1" | grep -Eq '"preRelease":[[:space:]]*true'
}

strip_hash_comment() {
    local line=$1
    line="${line#\#}"
    line="${line# }"
    printf '%s' "$line"
}

apply_bumps() {
    local infile=$1
    local outfile=$2
    local line check= match= title= upstream= skip=0 fetched=0
    local pending_sha= body= current new_url sha

    : > "$outfile"
    while IFS= read -r line || [ -n "${line:-}" ]; do
        line="${line%$'\r'}"

        if [ -z "$line" ]; then
            if [ -n "$pending_sha" ]; then
                echo "Expected checksum line, found blank" >&2
                exit 1
            fi
            check=
            match=
            title=
            upstream=
            skip=0
            fetched=0
            body=
            printf '\n' >> "$outfile"
            continue
        fi

        case "$line" in
            '#'*)
                if [ -n "$pending_sha" ]; then
                    echo "Expected checksum line, found comment" >&2
                    exit 1
                fi
                if [[ "$line" =~ ^#\ *check:\ *(.*)$ ]]; then
                    check="${BASH_REMATCH[1]}"
                    match=
                    upstream=
                    skip=0
                    fetched=0
                    body=
                elif [[ "$line" =~ ^#\ *match:\ *(.*)$ ]]; then
                    match="${BASH_REMATCH[1]}"
                    if [ -z "$check" ]; then
                        echo "Found # match: without # check:" >&2
                        exit 1
                    fi
                elif [ -z "$title" ]; then
                    title=$(strip_hash_comment "$line")
                fi
                printf '%s\n' "$line" >> "$outfile"
                continue
                ;;
        esac

        if [[ "$line" == */* ]]; then
            if [ -n "$pending_sha" ]; then
                echo "Expected checksum line, found URL" >&2
                exit 1
            fi
            if [ -n "$check" ] || [ -n "$match" ]; then
                if [ -z "$check" ] || [ -z "$match" ]; then
                    echo "Section '${title:-unknown}' needs both # check: and # match:" >&2
                    exit 1
                fi
                if [ "$fetched" -eq 0 ]; then
                    echo "${title:-unknown}: checking $check"
                    body=$(fetch_body "$check")
                    fetched=1
                    if is_prerelease "$body"; then
                        echo "${title:-unknown}: skip (preRelease:true)"
                        skip=1
                    else
                        upstream=$(max_match_version "$match" "$body")
                        if [ -z "$upstream" ]; then
                            echo "No matches for ${title:-unknown} pattern '$match' at $check" >&2
                            exit 1
                        fi
                        echo "${title:-unknown}: upstream $upstream"
                    fi
                fi
                if [ "$skip" -eq 0 ]; then
                    if [[ $line =~ $match ]]; then
                        current="${BASH_REMATCH[1]}"
                    else
                        echo "URL does not match pattern '$match': $line" >&2
                        exit 1
                    fi
                    if [ -z "$current" ]; then
                        echo "Empty version capture for $line" >&2
                        exit 1
                    fi
                    if ! version_le "$upstream" "$current"; then
                        new_url="${line//$current/$upstream}"
                        echo "${title:-unknown}: $current → $upstream"
                        sha=$(ensure_hashed "$new_url")
                        if [ -z "$sha" ]; then
                            echo "Failed to hash $new_url" >&2
                            exit 1
                        fi
                        line=$new_url
                        pending_sha=$sha
                    else
                        echo "${title:-unknown}: $current ≥ upstream $upstream (no bump)"
                    fi
                fi
            fi
            printf '%s\n' "$line" >> "$outfile"
            continue
        fi

        if [ -n "$pending_sha" ]; then
            printf '%s\n' "$pending_sha" >> "$outfile"
            pending_sha=
        else
            printf '%s\n' "$line" >> "$outfile"
        fi
    done < "$infile"

    if [ -n "$pending_sha" ]; then
        echo "MANIFEST ended waiting for a checksum" >&2
        exit 1
    fi
}

new_manifest=$(mktemp)
trap 'rm -f "$new_manifest"' EXIT
apply_bumps MANIFEST "$new_manifest"
if cmp -s MANIFEST "$new_manifest"; then
    echo "MANIFEST unchanged"
else
    mv "$new_manifest" MANIFEST
    echo "Wrote MANIFEST"
fi
