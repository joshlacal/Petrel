#!/usr/bin/env bash

# Builds the multi-target DocC static site and, with --publish, commits it to
# the docs-site branch that the static host serves.
#
# The generated site is not tracked on the main line (see .gitignore). It is
# built here, installed into docs/ for local preview, and published as a single
# commit on docs-site, an orphan branch that shares no ancestry with main. That
# keeps ~30,000 generated files out of main's history while still giving a
# branch-based host something to serve.

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)

BASE_PATH=${PETREL_DOCS_BASE_PATH:-Petrel}
BRANCH=${PETREL_DOCS_BRANCH:-docs-site}
PUBLISH=0
SWIFT=${PETREL_DOCS_SWIFT:-swift}

DEFAULT_TARGETS=(
  Petrel
  PetrelCore
  PetrelCrypto
  PetrelRepo
  PetrelFirehose
  PetrelJetstream
  PetrelPLC
  PetrelPLCPDS
  PetrelOAuthScopes
  PetrelOAuthServer
  PetrelOAuthServerLexicon
  PetrelOzone
  PetrelLexicon
)
TARGETS=()

usage() {
  cat >&2 <<'USAGE'
usage: Scripts/publish-documentation.sh [--base-path PATH] [--target TARGET ...] [--publish]

  --base-path PATH  URL subpath the site is served from, without slashes.
                    Defaults to "Petrel", which matches a project site served
                    at https://<host>/Petrel/. Use "" for a site served at the
                    domain root.
  --target TARGET   Build documentation for specific target(s). May be passed
                    multiple times. Defaults to all 13 documented Petrel library
                    targets merged into one combined DocC archive.
  --publish         After building, commit the site to the docs-site branch.
                    Pushing is left to you; this never contacts a remote.

environment:
  PETREL_DOCS_BASE_PATH  same as --base-path
  PETREL_DOCS_BRANCH     branch to publish to (default: docs-site)
  PETREL_DOCS_SWIFT      swift executable to use (default: swift)
USAGE
  exit 64
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --base-path) [[ $# -ge 2 ]] || usage; BASE_PATH=$2; shift 2 ;;
    --base-path=*) BASE_PATH=${1#*=}; shift ;;
    --target) [[ $# -ge 2 ]] || usage; TARGETS+=("$2"); shift 2 ;;
    --target=*) TARGETS+=("${1#*=}"); shift ;;
    --publish) PUBLISH=1; shift ;;
    -h | --help) usage ;;
    *) echo "unknown argument: $1" >&2; usage ;;
  esac
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  TARGETS=("${DEFAULT_TARGETS[@]}")
fi

fail() {
  echo "publish-documentation: $*" >&2
  exit 1
}

command -v "$SWIFT" >/dev/null 2>&1 || fail "swift executable not found: $SWIFT"

BUILD_ROOT=$ROOT/.build/documentation-site
OUTPUT=$BUILD_ROOT/Petrel.doccarchive-static

rm -rf -- "$BUILD_ROOT"
mkdir -p -- "$BUILD_ROOT"

echo "publish-documentation: building DocC site (base path: ${BASE_PATH:-/}, targets: ${TARGETS[*]})"

# SwiftPM #10285 makes Swift 6.4's default SwiftBuild path misclassify .docc
# catalogs. Use --build-system native on Swift 6.4 so catalogs remain discoverable.
package_args=(
  --scratch-path "$BUILD_ROOT/scratch"
  --allow-writing-to-directory "$OUTPUT"
)
swift_version_output=$("$SWIFT" --version 2>&1 || true)
if [[ $swift_version_output == *"Swift version 6.4"* ]]; then
  package_args=(--build-system native "${package_args[@]}")
fi

docc_target_args=()
if [[ ${#TARGETS[@]} -gt 1 ]]; then
  docc_target_args+=(--enable-experimental-combined-documentation)
fi
for target in "${TARGETS[@]}"; do
  docc_target_args+=(--target "$target")
done

# --transform-for-static-hosting rewrites the archive into a plain static tree.
# The base path must match the URL the host serves the site from, or every
# asset reference 404s.
hosting_args=(--transform-for-static-hosting)
if [[ -n $BASE_PATH ]]; then
  hosting_args+=(--hosting-base-path "$BASE_PATH")
fi

"$SWIFT" package \
  "${package_args[@]}" \
  generate-documentation \
  "${docc_target_args[@]}" \
  "${hosting_args[@]}" \
  --output-path "$OUTPUT"

[[ -f $OUTPUT/index.html ]] || fail "generated site is missing index.html"
[[ -d $OUTPUT/documentation ]] || fail "generated site is missing documentation/"

# GitHub Pages and any other Jekyll-processing host must be told not to eat
# directories beginning with an underscore.
touch "$OUTPUT/.nojekyll"

echo "publish-documentation: installing into docs/ for local preview"
"$ROOT/Scripts/install-generated-documentation.sh" "$OUTPUT"

if [[ $PUBLISH -eq 0 ]]; then
  cat <<EOF

Built: $OUTPUT
Installed for preview: $ROOT/docs

Preview it with:
  (cd $ROOT/docs && python3 -m http.server 8000)
  open http://localhost:8000/documentation/

Re-run with --publish to commit the site to the $BRANCH branch.
EOF
  exit 0
fi

command -v jj >/dev/null 2>&1 || fail "jj is required to publish; it is the only writer in this repository"

WORKSPACE=$ROOT/.build/documentation-site/workspace
rm -rf -- "$WORKSPACE"

echo "publish-documentation: publishing to $BRANCH"

# A separate workspace keeps this out of your current working copy, so an
# in-progress change is never disturbed. The commit is rooted at root(), which
# gives an orphan branch with no ancestry in main.
jj --repository "$ROOT" workspace add --name "docs-site-publish" "$WORKSPACE" >/dev/null
cleanup() {
  jj --repository "$ROOT" workspace forget "docs-site-publish" >/dev/null 2>&1 || true
  rm -rf -- "$WORKSPACE"
}
trap cleanup EXIT

# DocC's search index carries individual files of several megabytes
# (index/data.mdb, index/index.json, index/navigator.index). jj's default
# snapshot.max-new-file-size is 1 MiB and it *warns and skips* rather than
# failing, which silently publishes a site whose search and navigator are
# broken. Raise the limit for these commands only, so the repository's own
# guard against stray large files stays in place.
JJ_SNAPSHOT_LIMIT=${PETREL_DOCS_MAX_FILE_SIZE:-67108864}
jj_publish() {
  jj --config "snapshot.max-new-file-size=$JJ_SNAPSHOT_LIMIT" "$@"
}

(
  cd "$WORKSPACE"
  # 'root()' must be quoted; bare parentheses are a shell syntax error.
  jj_publish new 'root()' >/dev/null

  # Clear whatever the workspace materialised, then lay down only the site.
  find . -mindepth 1 -maxdepth 1 ! -name '.jj' -exec rm -rf -- {} +
  cp -R -- "$OUTPUT/." .
  touch .nojekyll

  jj_publish describe -m "docs: publish DocC site (base path: ${BASE_PATH:-/})" >/dev/null
  jj_publish bookmark set "$BRANCH" -r @ >/dev/null
)

# A skipped file is a warning, not an error, so compare counts rather than
# trusting the exit status.
expected=$(find "$OUTPUT" -type f | wc -l | tr -d ' ')
published=$(jj --repository "$ROOT" file list -r "$BRANCH" 2>/dev/null | wc -l | tr -d ' ')
if [[ $expected != "$published" ]]; then
  fail "published $published files but the site has $expected; jj skipped some (raise PETREL_DOCS_MAX_FILE_SIZE)"
fi
echo "publish-documentation: published $published files"

cat <<EOF

Published locally to the $BRANCH bookmark. Nothing was pushed.

Review it:
  jj log -r $BRANCH
  jj file list -r $BRANCH | head

Push it when you are ready:
  jj git push --bookmark $BRANCH
EOF
