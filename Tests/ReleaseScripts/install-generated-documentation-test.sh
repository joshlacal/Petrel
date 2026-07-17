#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT=$ROOT/Scripts/install-generated-documentation.sh
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

make_repository() {
  local repository=$1

  mkdir -p "$repository/Scripts" "$repository/docs/releases"
  cp "$SCRIPT" "$repository/Scripts/install-generated-documentation.sh"
  chmod +x "$repository/Scripts/install-generated-documentation.sh"
  printf 'hand-authored-marker\n' > "$repository/docs/.nojekyll"
  printf 'release-note\n' > "$repository/docs/releases/0.2.0.md"
  printf 'stale\n' > "$repository/docs/index.html"
  mkdir -p "$repository/docs/documentation"
  printf 'stale\n' > "$repository/docs/documentation/stale.html"
}

make_output() {
  local output=$1

  mkdir -p \
    "$output/css" \
    "$output/documentation/petrel" \
    "$output/downloads" \
    "$output/images" \
    "$output/videos"
  printf 'generated-marker\n' > "$output/.nojekyll"
  printf 'fresh-index\n' > "$output/index.html"
  printf 'fresh-docs\n' > "$output/documentation/petrel/index.html"
  printf 'fresh-css\n' > "$output/css/site.css"
  printf '{}\n' > "$output/theme-settings.json"
}

repository=$TMP/success/repository
output=$TMP/success/output
make_repository "$repository"
make_output "$output"
"$repository/Scripts/install-generated-documentation.sh" "$output"

test "$(cat "$repository/docs/releases/0.2.0.md")" = release-note
test "$(cat "$repository/docs/.nojekyll")" = hand-authored-marker
test "$(cat "$repository/docs/index.html")" = fresh-index
test "$(cat "$repository/docs/documentation/petrel/index.html")" = fresh-docs
test "$(cat "$repository/docs/css/site.css")" = fresh-css
test "$(cat "$repository/docs/theme-settings.json")" = '{}'
test ! -e "$repository/docs/documentation/stale.html"

repository=$TMP/unexpected/repository
output=$TMP/unexpected/output
make_repository "$repository"
make_output "$output"
mkdir -p "$output/releases"
printf 'injected\n' > "$output/releases/0.2.0.md"
if "$repository/Scripts/install-generated-documentation.sh" "$output"; then
  echo "unexpected generated top-level paths must fail closed" >&2
  exit 1
fi
test "$(cat "$repository/docs/releases/0.2.0.md")" = release-note
test "$(cat "$repository/docs/index.html")" = stale

repository=$TMP/symlink/repository
output=$TMP/symlink/output
make_repository "$repository"
make_output "$output"
ln -s /tmp "$output/documentation/external"
if "$repository/Scripts/install-generated-documentation.sh" "$output"; then
  echo "generated documentation symlinks must fail closed" >&2
  exit 1
fi
test "$(cat "$repository/docs/releases/0.2.0.md")" = release-note
test "$(cat "$repository/docs/index.html")" = stale

repository=$TMP/same-tree/repository
make_repository "$repository"
if "$repository/Scripts/install-generated-documentation.sh" "$repository/docs"; then
  echo "the generated source and installed destination must differ" >&2
  exit 1
fi
test "$(cat "$repository/docs/releases/0.2.0.md")" = release-note
test "$(cat "$repository/docs/index.html")" = stale

echo "generated documentation installer contract: PASS"
