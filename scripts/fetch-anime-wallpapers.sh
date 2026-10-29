#!/usr/bin/env bash
# Fetch SFW anime wallpapers from the wallhaven.cc API (toplist) into
# ~/Pictures/Wallpapers/anime. Files already present are skipped by wallhaven
# id, so re-running the script only downloads what is missing.
# Usage:
#   scripts/fetch-anime-wallpapers.sh [count] [outdir]
set -euo pipefail

COUNT="${1:-24}"
OUTDIR="${2:-$HOME/Pictures/Wallpapers/anime}"
API="https://wallhaven.cc/api/v1/search"
MAX_PAGES=6

have() { command -v "$1" >/dev/null 2>&1; }
have curl || { echo "curl is required" >&2; exit 1; }
have jq || { echo "jq is required" >&2; exit 1; }

mkdir -p "$OUTDIR"

# Anime category (010), SFW purity (100), 16:9 and at least Full-HD.
query="$API?categories=010&purity=100&sorting=toplist&topRange=1y&atleast=1920x1080&ratios=16x9"

have_id() { # id dir -> print the path if a wallhaven-<id>.* file is already there
  find "$2" -maxdepth 1 -type f -name "wallhaven-$1.*" -print -quit
}

downloaded=0
page=1
while (( downloaded < COUNT && page <= MAX_PAGES )); do
  response=$(curl -fsSL "${query}&page=${page}") || { echo "API page $page failed" >&2; break; }
  while IFS=$'\t' read -r id path; do
    [ -n "$id" ] && [ -n "$path" ] || continue
    if [ -n "$(have_id "$id" "$OUTDIR")" ]; then continue; fi
    target="$OUTDIR/wallhaven-${id}.${path##*.}"
    echo "Downloading ${id} ..."
    if ! curl -fsSL --retry 2 -o "$target" "$path"; then
      rm -f "$target"
      continue
    fi
    if have identify && ! identify -quiet "$target" >/dev/null 2>&1; then
      echo "Not an image, dropping ${id}" >&2
      rm -f "$target"
      continue
    fi
    downloaded=$((downloaded + 1))
    sleep 1
    if (( downloaded >= COUNT )); then break; fi
  done < <(jq -r '.data[] | [.id, .path] | @tsv' <<<"$response")
  page=$((page + 1))
done

echo "Done: $downloaded new wallpapers in $OUTDIR ($(find "$OUTDIR" -maxdepth 1 -type f | wc -l) files total)"
