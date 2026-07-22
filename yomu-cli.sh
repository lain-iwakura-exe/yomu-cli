#!/usr/bin/env bash
#
# yomu-cli.sh — Read manga straight from your terminal.
# Source: MangaDex API (https://api.mangadex.org)
# Requires: curl, jq, fzf, and either chafa or kitty (for icat)
#
set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

API="https://api.mangadex.org"
RENDERER="chafa"          # chafa | kitty
LANG_FILTER="en"
TMP_DIR="$(mktemp -d /tmp/yomu-cli.XXXXXX)"

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
die() {
  echo "Error: $*" >&2
  exit 1
}

check_deps() {
  local missing=()
  for bin in curl jq fzf; do
    command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
  done

  if [[ "$RENDERER" == "chafa" ]]; then
    command -v chafa >/dev/null 2>&1 || missing+=("chafa")
  else
    command -v kitty >/dev/null 2>&1 || missing+=("kitty (for icat)")
  fi

  if (( ${#missing[@]} > 0 )); then
    die "missing dependencies: ${missing[*]}. See README.md for install instructions."
  fi
}

usage() {
  cat <<'EOF'
Yomu CLI — read manga in your terminal

Usage: yomu-cli [manga name] [options]

Examples:
  yomu-cli                     interactive search prompt
  yomu-cli "one piece"         search and jump straight to results
  yomu-cli "berserk" --kitty   search, render with kitty icat

Options:
  -k, --kitty     Render pages with `kitty +kitten icat` instead of chafa
  -c, --chafa     Render pages with chafa (default)
  -l, --lang CODE Filter chapters by language code (default: en)
  -h, --help      Show this help

Controls while reading:
  [enter] / n     next page
  p               previous page
  q               quit reader
EOF
}

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
QUERY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -k|--kitty) RENDERER="kitty"; shift ;;
    -c|--chafa) RENDERER="chafa"; shift ;;
    -l|--lang) LANG_FILTER="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *) QUERY="$1"; shift ;;
  esac
done

# ---------------------------------------------------------------------------
# Step 1: search manga
# ---------------------------------------------------------------------------
search_manga() {
  local query="$1"
  curl -s --get "$API/manga" \
    --data-urlencode "title=$query" \
    --data-urlencode "limit=20" \
    --data-urlencode "order[relevance]=desc" \
    --data-urlencode "contentRating[]=safe" \
    --data-urlencode "contentRating[]=suggestive"
}

pick_manga() {
  local query="$1"
  local json
  json="$(search_manga "$query")"

  local count
  count="$(echo "$json" | jq '.data | length')"
  (( count > 0 )) || die "no manga found for '$query'."

  local selection
  selection="$(echo "$json" | jq -r '
    .data[] |
    [.id, (.attributes.title.en // (.attributes.title | to_entries[0].value) // "Untitled"),
     (.attributes.year // "????")] |
    @tsv
  ' | awk -F'\t' '{printf "%s\t%s (%s)\n", $1, $2, $3}' \
    | fzf --with-nth=2 --delimiter='\t' --prompt="Select manga > " --height=80% --border)" || true

  [[ -n "${selection:-}" ]] || die "no selection made."
  echo "$selection" | cut -f1
}

# ---------------------------------------------------------------------------
# Step 2: list & pick chapters
# ---------------------------------------------------------------------------
fetch_chapters() {
  local manga_id="$1"
  curl -s --get "$API/manga/$manga_id/feed" \
    --data-urlencode "translatedLanguage[]=$LANG_FILTER" \
    --data-urlencode "order[volume]=asc" \
    --data-urlencode "order[chapter]=asc" \
    --data-urlencode "limit=500" \
    --data-urlencode "contentRating[]=safe" \
    --data-urlencode "contentRating[]=suggestive"
}

pick_chapter() {
  local manga_id="$1"
  local json
  json="$(fetch_chapters "$manga_id")"

  local count
  count="$(echo "$json" | jq '.data | length')"
  (( count > 0 )) || die "no chapters found for language '$LANG_FILTER'."

  local selection
  selection="$(echo "$json" | jq -r '
    .data[] |
    [.id,
     (.attributes.volume // "-"),
     (.attributes.chapter // "-"),
     (.attributes.title // "")] |
    @tsv
  ' | awk -F'\t' '{printf "%s\tVol %s, Ch %s — %s\n", $1, $2, $3, $4}' \
    | fzf --with-nth=2 --delimiter='\t' --prompt="Select chapter > " --height=80% --border)" || true

  [[ -n "${selection:-}" ]] || die "no selection made."
  echo "$selection" | cut -f1
}

# ---------------------------------------------------------------------------
# Step 3: resolve image server & download pages
# ---------------------------------------------------------------------------
download_chapter() {
  local chapter_id="$1"
  local json
  json="$(curl -s "$API/at-home/server/$chapter_id")"

  local base_url hash
  base_url="$(echo "$json" | jq -r '.baseUrl')"
  hash="$(echo "$json" | jq -r '.chapter.hash')"

  local files
  mapfile -t files < <(echo "$json" | jq -r '.chapter.data[]')

  (( ${#files[@]} > 0 )) || die "no pages found for this chapter."

  echo "Downloading ${#files[@]} pages..." >&2

  local i=0
  for f in "${files[@]}"; do
    i=$((i + 1))
    local out
    out="$(printf "%s/%03d_%s" "$TMP_DIR" "$i" "$f")"
    curl -s "$base_url/data/$hash/$f" -o "$out"
  done
}

# ---------------------------------------------------------------------------
# Step 4: render pages
# ---------------------------------------------------------------------------
render_page() {
  local file="$1"
  clear
  if [[ "$RENDERER" == "kitty" ]]; then
    kitty +kitten icat --clear --transfer-mode=stream "$file"
  else
    chafa --size="$(tput cols)x$(tput lines)" "$file"
  fi
}

read_chapter() {
  local pages
  mapfile -t pages < <(find "$TMP_DIR" -type f | sort)
  (( ${#pages[@]} > 0 )) || die "no pages downloaded."

  local idx=0
  local total=${#pages[@]}

  while true; do
    render_page "${pages[$idx]}"
    echo
    echo "Page $((idx + 1))/$total — [enter/n] next  [p] previous  [q] quit"
    read -rsn1 key || true
    case "$key" in
      q|Q) break ;;
      p|P) (( idx > 0 )) && idx=$((idx - 1)) ;;
      *) (( idx < total - 1 )) && idx=$((idx + 1)) || break ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  check_deps

  local query="$QUERY"
  if [[ -z "$query" ]]; then
    read -rp "Search manga title: " query
    [[ -n "$query" ]] || die "search query cannot be empty."
  fi

  local manga_id
  manga_id="$(pick_manga "$query")"

  local chapter_id
  chapter_id="$(pick_chapter "$manga_id")"

  download_chapter "$chapter_id"
  read_chapter
}

main "$@"
