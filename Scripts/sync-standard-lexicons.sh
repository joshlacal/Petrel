#!/usr/bin/env bash
# Preserve the separately reviewed alpha corpus while syncing stable namespaces.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${1:?usage: sync-standard-lexicons.sh upstream-lexicons [destination]}"
DESTINATION="${2:-$ROOT/generator/lexicons}"
PYTHON="${PETREL_PYTHON:-python3}"
"$PYTHON" "$ROOT/Scripts/space_lexicon_provenance.py" verify --lexicons "$DESTINATION"
for ns in app chat com tools site; do
  rsync -a --delete --exclude='/atproto/space/' --exclude='/atproto/simplespace/' \
    "$SOURCE/$ns/" "$DESTINATION/$ns/"
done
"$PYTHON" "$ROOT/Scripts/space_lexicon_provenance.py" verify --lexicons "$DESTINATION"
