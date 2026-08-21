#!/usr/bin/env bash
# Petrel/Scripts/vendor-space-lexicons.sh
# Vendors com.atproto.space + com.atproto.simplespace lexicons from a pinned
# SHA of bluesky-social/atproto (permissioned-data branch). Re-run with a new
# SHA on upstream Thursday alpha drops.
set -euo pipefail
SHA="${1:?usage: vendor-space-lexicons.sh <atproto-commit-sha>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fsSL "https://github.com/bluesky-social/atproto/archive/${SHA}.tar.gz" \
  | tar -xz -C "$TMP" --strip-components=1 \
      "atproto-${SHA}/lexicons/com/atproto/space" \
      "atproto-${SHA}/lexicons/com/atproto/simplespace"
for ns in space simplespace; do
  rm -rf "$ROOT/generator/lexicons/com/atproto/$ns"
  cp -R "$TMP/lexicons/com/atproto/$ns" "$ROOT/generator/lexicons/com/atproto/$ns"
done
echo "$SHA" > "$ROOT/generator/lexicons/com/atproto/space/.pin"
echo "Vendored space lexicons at $SHA"
