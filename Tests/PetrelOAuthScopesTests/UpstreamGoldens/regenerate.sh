#!/usr/bin/env bash
#
# Regenerates ../Fixtures/upstream-oauth-scopes.json from the reference
# implementation's own @atproto/oauth-scopes, at the commit pinned in
# generate.mjs.
#
# Usage:
#   Tests/PetrelOAuthScopesTests/UpstreamGoldens/regenerate.sh /path/to/atproto [--check]
#
# /path/to/atproto must be a clean checkout of bluesky-social/atproto at the
# pinned commit. It is never modified: the three packages the generator needs
# are copied to a temporary directory first. With --check the fixture is not
# written; the script exits non-zero if regenerating would change it.
#
# Requires git, node (>= 20) and npm. npm fetches three pinned packages.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fixture="$here/../Fixtures/upstream-oauth-scopes.json"

fail() { printf 'regenerate.sh: %s\n' "$1" >&2; exit 1; }

upstream="${1:-}"
mode="${2:-}"
[ -n "$upstream" ] || fail "usage: regenerate.sh /path/to/atproto [--check]"
[ -d "$upstream/packages/oauth/oauth-scopes/src" ] || fail "$upstream is not an atproto checkout"

reference_commit="$(sed -n "s/^const REFERENCE_COMMIT = '\([0-9a-f]\{40\}\)'$/\1/p" "$here/generate.mjs")"
[ -n "$reference_commit" ] || fail "could not read REFERENCE_COMMIT from generate.mjs"

actual_commit="$(git -C "$upstream" rev-parse HEAD)"
[ "$actual_commit" = "$reference_commit" ] || fail \
  "$upstream is at $actual_commit; generate.mjs pins $reference_commit"

packages=(packages/did packages/syntax packages/oauth/oauth-scopes)
[ -z "$(git -C "$upstream" status --porcelain -- "${packages[@]}")" ] || fail \
  "$upstream has local changes under ${packages[*]}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

for package in "${packages[@]}"; do
  mkdir -p "$work/up/$(dirname "$package")"
  git -C "$upstream" archive HEAD -- "$package" | tar -x -C "$work/up"
done

cd "$work"
cat > package.json <<'JSON'
{
  "private": true,
  "dependencies": {
    "esbuild": "0.25.0",
    "iso-datestring-validator": "2.2.2",
    "zod": "3.24.2"
  }
}
JSON
npm install --ignore-scripts --no-audit --no-fund --loglevel=error >/dev/null

# Link the workspace packages after installing: npm prunes links it did not
# create. Each package's entry points name ./dist, which an unbuilt checkout
# does not have, so point them at the TypeScript source instead.
mkdir -p node_modules/@atproto
for package in "${packages[@]}"; do
  node -e '
    const fs = require("node:fs")
    const file = process.argv[1] + "/package.json"
    const manifest = JSON.parse(fs.readFileSync(file, "utf8"))
    delete manifest.exports
    manifest.main = "./src/index.ts"
    fs.writeFileSync(file, JSON.stringify(manifest, null, 2))
  ' "$work/up/$package"
  ln -s "$work/up/$package" "node_modules/@atproto/$(basename "$package")"
done
ln -s "$work/node_modules" "$work/up/node_modules"

cp "$here/generate.mjs" generate.mjs
node_modules/.bin/esbuild generate.mjs --bundle --platform=node --format=esm \
  --outfile=generate.bundle.mjs --log-level=warning
node generate.bundle.mjs > corpus.json

if [ "$mode" = "--check" ]; then
  diff -u "$fixture" corpus.json || fail "the checked-in fixture differs from a fresh run"
  printf 'regenerate.sh: fixture matches %s\n' "$reference_commit"
else
  cp corpus.json "$fixture"
  printf 'regenerate.sh: wrote %s from %s\n' "$fixture" "$reference_commit"
fi
