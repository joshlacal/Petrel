#!/usr/bin/env bash
# Sync the standard Lexicon namespaces from their canonical upstream repositories.
#
#   com.atproto, tools.ozone            <- bluesky-social/atproto  (lexicons/)
#   app.bsky, chat.bsky, network.bsky   <- bluesky-social/bsky     (lexicons/)
#
# Each namespace is mirrored exactly (files removed upstream are removed here). Everything
# else under generator/lexicons is left alone: the separately reviewed Spaces alpha corpus
# (com.atproto.space and friends, see generator/provenance/spaces.json) and third-party
# namespaces vendored by hand (com.germnetwork, site.standard).
#
# The commits that were synced are recorded in generator/provenance/standard-lexicons.json.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
usage="usage: sync-standard-lexicons.sh <atproto-lexicons-dir> <atproto-commit> <bsky-lexicons-dir> <bsky-commit> [destination]"
ATPROTO_SOURCE="${1:?$usage}"
ATPROTO_COMMIT="${2:?$usage}"
BSKY_SOURCE="${3:?$usage}"
BSKY_COMMIT="${4:?$usage}"
DESTINATION="${5:-$ROOT/generator/lexicons}"
PYTHON="${PETREL_PYTHON:-python3}"

for commit in "$ATPROTO_COMMIT" "$BSKY_COMMIT"; do
  [[ $commit =~ ^[0-9a-f]{40}$ ]] || { echo "not a full commit id: $commit" >&2; exit 1; }
done

"$PYTHON" "$ROOT/Scripts/space_lexicon_provenance.py" verify --lexicons "$DESTINATION"

sync_namespace() {
  local source=$1 namespace=$2
  shift 2
  [[ -d $source/$namespace ]] || { echo "upstream has no $namespace under $source" >&2; exit 1; }
  mkdir -p "$DESTINATION/$namespace"
  rsync -a --delete "$@" "$source/$namespace/" "$DESTINATION/$namespace/"
}

sync_namespace "$ATPROTO_SOURCE" com/atproto \
  --exclude='/space/' --exclude='/memberspace/' --exclude='/managedspace/' --exclude='/personalspace/'
sync_namespace "$ATPROTO_SOURCE" tools/ozone
sync_namespace "$BSKY_SOURCE" app/bsky
sync_namespace "$BSKY_SOURCE" chat/bsky
sync_namespace "$BSKY_SOURCE" network/bsky

"$PYTHON" "$ROOT/Scripts/space_lexicon_provenance.py" verify --lexicons "$DESTINATION"

cat > "$ROOT/generator/provenance/standard-lexicons.json" <<JSON
{
  "\$comment": "Written by Scripts/sync-standard-lexicons.sh. The upstream commits the standard namespaces under generator/lexicons were mirrored from.",
  "sources": [
    {
      "repository": "https://github.com/bluesky-social/atproto",
      "commit": "$ATPROTO_COMMIT",
      "path": "lexicons",
      "namespaces": ["com.atproto", "tools.ozone"]
    },
    {
      "repository": "https://github.com/bluesky-social/bsky",
      "commit": "$BSKY_COMMIT",
      "path": "lexicons",
      "namespaces": ["app.bsky", "chat.bsky", "network.bsky"]
    }
  ]
}
JSON
