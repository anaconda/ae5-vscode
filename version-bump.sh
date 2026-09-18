#!/bin/bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: version-bump.sh [--dry-run]

Compare origin/master MANIFEST to upstream versions declared by
# check: / # match: comments and open, update, or close the single
bot/vscode-version PR as needed.

  --dry-run   Rewrite MANIFEST in place if versions changed; report the
              PR action that would be taken. Do not create, close, or
              modify a PR, and do not commit or push.
EOF
}

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "Unknown argument: $arg" >&2
            usage >&2
            exit 1
            ;;
    esac
done

cd "$(dirname "${BASH_SOURCE[0]}")"

BOT_BRANCH=bot/vscode-version
CHANGES_FILE=/tmp/vscode-bump-changes.txt
: > "$CHANGES_FILE"

owner="${GITHUB_REPOSITORY_OWNER:-}"
if [ -z "$owner" ]; then
    origin_url=$(git remote get-url origin)
    owner=$(printf '%s\n' "$origin_url" | sed -n 's/.*github.com[:/]\([^/]*\)\/.*/\1/p')
fi
if [ -z "$owner" ]; then
    echo "Could not determine GitHub repository owner" >&2
    exit 1
fi

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

record_change() {
    local title=$1 old=$2 new=$3 src=$4
    if grep -F "${title}	" "$CHANGES_FILE" >/dev/null 2>&1; then
        return 0
    fi
    printf '%s\t%s\t%s\t%s\n' "$title" "$old" "$new" "$src" >> "$CHANGES_FILE"
}

fetch_body() {
    curl -fsSL -A 'ae5-vscode-version-bump' "$1"
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
                        record_change "${title:-unknown}" "$current" "$upstream" "$check"
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

pr_title_from_changes() {
    local n title old new src
    n=$(grep -c . "$CHANGES_FILE" || true)
    if [ "$n" -eq 1 ]; then
        IFS='	' read -r title old new src < "$CHANGES_FILE"
        printf 'chore: bump %s to %s\n' "$title" "$new"
    else
        printf 'chore: bump vscode MANIFEST\n'
    fi
}

write_pr_body() {
    local title old new src
    {
        echo 'Automated VSCode MANIFEST version bump.'
        echo
        while IFS='	' read -r title old new src; do
            [ -n "$title" ] || continue
            echo "- ${title}: \`${old}\` → \`${new}\`"
            echo "  Source: ${src}"
        done < "$CHANGES_FILE"
        echo
        echo 'Main CI will run `download_vscode.sh` / bringup against this MANIFEST.'
    } > /tmp/pr-body.md
}

close_pr() {
    local reason=$1
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "DRY-RUN: would close PR #$pr_number: $reason"
        pr_number=
        return
    fi
    echo "Closing PR #$pr_number: $reason"
    gh pr close "$pr_number" --comment "$reason"
    pr_number=
}

# --- apply ---

new_manifest=$(mktemp)
if [ "$DRY_RUN" -eq 1 ]; then
    apply_bumps MANIFEST "$new_manifest"
    if cmp -s MANIFEST "$new_manifest"; then
        echo "MANIFEST unchanged"
        rm -f "$new_manifest"
    else
        mv "$new_manifest" MANIFEST
        echo "Wrote MANIFEST"
    fi
else
    git fetch origin master
    git fetch origin "${BOT_BRANCH}:refs/remotes/origin/${BOT_BRANCH}" 2>/dev/null || true
    git show origin/master:MANIFEST > /tmp/master-MANIFEST
    apply_bumps /tmp/master-MANIFEST "$new_manifest"
fi

git fetch origin master
git fetch origin "${BOT_BRANCH}:refs/remotes/origin/${BOT_BRANCH}" 2>/dev/null || true

pr_number=$(gh pr list --head "${owner}:${BOT_BRANCH}" --state open --json number --jq '.[0].number // empty')
if [ -n "$pr_number" ]; then
    echo "Open bump PR #$pr_number"
fi

if [ "$DRY_RUN" -eq 1 ]; then
    generated=MANIFEST
else
    generated=$new_manifest
fi

master_manifest=$(mktemp)
git show origin/master:MANIFEST > "$master_manifest"

if cmp -s "$generated" "$master_manifest"; then
    if [ -n "$pr_number" ]; then
        close_pr "master already has these MANIFEST versions. Closing."
    else
        echo "No bump needed: generated MANIFEST matches origin/master"
    fi
    rm -f "$master_manifest"
    [ "$DRY_RUN" -eq 1 ] || rm -f "$new_manifest"
    exit 0
fi

if [ -n "$pr_number" ] && git rev-parse --verify "origin/${BOT_BRANCH}" >/dev/null 2>&1; then
    pr_manifest=$(mktemp)
    if git show "origin/${BOT_BRANCH}:MANIFEST" > "$pr_manifest" 2>/dev/null; then
        if cmp -s "$generated" "$pr_manifest"; then
            echo "Open PR #$pr_number already has this MANIFEST"
            rm -f "$pr_manifest" "$master_manifest"
            [ "$DRY_RUN" -eq 1 ] || rm -f "$new_manifest"
            exit 0
        fi
    fi
    rm -f "$pr_manifest"
fi

title=$(pr_title_from_changes)
if [ "$DRY_RUN" -eq 1 ]; then
    if [ -n "$pr_number" ]; then
        echo "DRY-RUN: would update PR #$pr_number: $title"
    else
        echo "DRY-RUN: would create PR '$title'"
    fi
    rm -f "$master_manifest"
    exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git checkout --no-track -B "$BOT_BRANCH" origin/master
cp "$new_manifest" MANIFEST
rm -f "$new_manifest" "$master_manifest"
if git diff --quiet MANIFEST; then
    echo "No change after bump; unexpected" >&2
    exit 1
fi

printf '%s\n' "$title" > /tmp/commit-msg.txt
git add MANIFEST
git commit -F /tmp/commit-msg.txt
git push --force origin "$BOT_BRANCH"

write_pr_body
if [ -n "$pr_number" ]; then
    gh pr edit "$pr_number" --title "$title" --body-file /tmp/pr-body.md
    echo "Updated PR #$pr_number"
else
    gh pr create --base master --head "$BOT_BRANCH" --title "$title" --body-file /tmp/pr-body.md
fi
