#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
DESTINATION=$ROOT/docs

fail() {
  echo "generated documentation install: $*" >&2
  exit 1
}

[[ $# -eq 1 ]] || fail "usage: $0 GENERATED_OUTPUT_DIRECTORY"
[[ -d $1 ]] || fail "generated output is not a directory: $1"
[[ -d $DESTINATION ]] || fail "documentation destination is missing: $DESTINATION"

SOURCE=$(cd "$1" && pwd -P)
DESTINATION=$(cd "$DESTINATION" && pwd -P)
[[ $SOURCE != "$DESTINATION" ]] || fail "generated output and destination must differ"
case "$SOURCE/" in
  "$DESTINATION/"*) fail "generated output must not be inside the destination" ;;
esac
case "$DESTINATION/" in
  "$SOURCE/"*) fail "destination must not be inside the generated output" ;;
esac

is_generated_entry() {
  case $1 in
    .nojekyll | css | data | developer-og-twitter.jpg | developer-og.jpg | \
      documentation | downloads | favicon.ico | favicon.svg | images | img | \
      index | index.html | js | metadata.json | theme-settings.json | videos)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

[[ -f $SOURCE/index.html ]] || fail "generated output is missing index.html"
[[ -d $SOURCE/documentation ]] || fail "generated output is missing documentation/"
[[ -z $(find "$SOURCE" -type l -print -quit) ]] || \
  fail "generated output must not contain symbolic links"

while IFS= read -r -d '' path; do
  entry=${path##*/}
  is_generated_entry "$entry" || fail "unexpected generated top-level entry: $entry"
done < <(find "$SOURCE" -mindepth 1 -maxdepth 1 -print0)

generated_entries=(
  css
  data
  developer-og-twitter.jpg
  developer-og.jpg
  documentation
  downloads
  favicon.ico
  favicon.svg
  images
  img
  index
  index.html
  js
  metadata.json
  theme-settings.json
  videos
)

for entry in "${generated_entries[@]}"; do
  rm -rf -- "${DESTINATION:?}/$entry"
  if [[ -e $SOURCE/$entry ]]; then
    cp -R -- "$SOURCE/$entry" "$DESTINATION/$entry"
  fi
done
