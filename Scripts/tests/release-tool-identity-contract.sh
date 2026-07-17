#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/petrel-tool-identity.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

source "$ROOT/Scripts/release-tool-identity.sh"

cp /bin/sh "$TMP/selected-swift"
ln -s selected-swift "$TMP/xcrun-swift"
cp /bin/sh "$TMP/wrong-swift"

petrel_release_same_file_identity \
  "$TMP/selected-swift" "$TMP/xcrun-swift" || {
  echo "filesystem aliases to the selected tool must be accepted" >&2
  exit 1
}

if petrel_release_same_file_identity \
  "$TMP/selected-swift" "$TMP/wrong-swift"; then
  echo "a different toolchain binary must be rejected" >&2
  exit 1
fi
