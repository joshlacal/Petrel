#!/usr/bin/env bash
# Checks the OAuth server package traits the way a user meets them: through a
# repository URL and a tagged version, not a path dependency.
#
# A snapshot of this checkout becomes a throwaway Git repository tagged 99.0.0.
# Scratch consumers then depend on it by file:// URL:
#
#   1. Petrel only, no traits (Tests/ReleaseConsumers/PetrelURLConsumer):
#      builds, and no SwiftNIO or Hummingbird module is compiled.
#   2. The OAuth server consumer with no traits: on Swift 6.2 and later its
#      Package.resolved has no swift-nio, swift-nio-ssl or hummingbird pin
#      (Swift 6.1 fetches trait-guarded dependencies, so that check is skipped
#      there); using PinnedNIOOAuthRemoteTransport or the Hummingbird adapter
#      fails with a message that names the trait.
#   3. With traits: ["OAuthServerNIO"]: resolves swift-nio and swift-nio-ssl
#      but not hummingbird, builds, and runs.
#   4. With traits: ["OAuthServerHummingbird"]: resolves hummingbird, and the
#      NIO product is enabled through it.
#
# usage: oauth-server-traits-contract.sh
# Uses $RELEASE_SWIFT when set, else swift on PATH. Needs network access to
# resolve Petrel's other dependencies.

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
SWIFT=${RELEASE_SWIFT:-$(command -v swift)}
GIT=/usr/bin/git
TMP=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/petrel-oauth-traits.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "oauth-server traits contract: $*" >&2
  exit 1
}

read -r SWIFT_MAJOR SWIFT_MINOR < <(
  "$SWIFT" --version 2>/dev/null | sed -nE 's/.*Swift version ([0-9]+)\.([0-9]+).*/\1 \2/p' | head -n 1
)
[[ -n ${SWIFT_MAJOR:-} ]] || fail "cannot read the Swift version from $SWIFT"
PRUNES_TRAIT_DEPENDENCIES=0
if ((SWIFT_MAJOR > 6 || (SWIFT_MAJOR == 6 && SWIFT_MINOR >= 2))); then
  PRUNES_TRAIT_DEPENDENCIES=1
fi
echo "Swift $SWIFT_MAJOR.$SWIFT_MINOR ($SWIFT)"

# --- snapshot of the commit under test, as a tagged repository -----------------
SNAPSHOT=$TMP/petrel
mkdir -p "$SNAPSHOT"
(
  cd "$ROOT"
  "$GIT" ls-files -z --cached --others --exclude-standard |
    while IFS= read -r -d '' path; do
      [[ -f $path ]] && printf '%s\0' "$path"
    done |
    tar --null -T - -cf -
) | tar -xf - -C "$SNAPSHOT"
snapshot_git() {
  env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
    "$GIT" -C "$SNAPSHOT" -c user.name=contract -c user.email=contract@example.invalid "$@"
}
snapshot_git init -q
snapshot_git add -A
snapshot_git commit -q -m snapshot
snapshot_git tag 99.0.0
PETREL_URL="file://$SNAPSHOT"

# consumer NAME FIXTURE REPLACEMENT_DEPENDENCY_LINE
consumer() {
  # The directory name becomes the consumer's package identity, so it must not
  # collide with a dependency's (a consumer called "hummingbird" would stand in
  # for the real package).
  local dir=$TMP/$1 fixture=$ROOT/Tests/ReleaseConsumers/$2 line=$3 manifest escaped
  cp -R "$fixture" "$dir"
  manifest=$dir/Package.swift
  [[ $(grep -c '\.package(url: "https://github\.com/joshlacal/Petrel\.git"' "$manifest") == 1 ]] ||
    fail "$manifest: expected one Petrel dependency"
  escaped=$(printf '%s' "${line//PETREL_URL/$PETREL_URL}" | sed 's/[&|\\]/\\&/g')
  sed -i.bak -E "s|^([[:space:]]*)\.package\(url: \"https://github\.com/joshlacal/Petrel\.git\".*$|\1$escaped|" "$manifest"
  rm -f "$manifest.bak"
  grep -F "$PETREL_URL" "$manifest" >/dev/null || fail "$1: the Petrel URL was not rewritten"
  "$SWIFT" package --package-path "$dir" --scratch-path "$dir/.build" resolve >/dev/null
}

pinned() {
  grep -Eq "\"identity\" *: *\"$2\"" "$TMP/$1/Package.resolved"
}

expect_unpinned_unless_61() {
  local name=$1
  shift
  if ((PRUNES_TRAIT_DEPENDENCIES == 0)); then
    echo "skip ($name): Swift $SWIFT_MAJOR.$SWIFT_MINOR resolves trait-guarded dependencies; it fetches $* but does not build them"
    return
  fi
  for identity in "$@"; do
    ! pinned "$name" "$identity" || fail "$name resolved $identity without the trait that needs it"
  done
}

expect_no_modules() {
  local name=$1
  shift
  for module in "$@"; do
    [[ -z $(find "$TMP/$name/.build" -name "$module.swiftmodule" -print -quit) ]] ||
      fail "$name compiled $module"
  done
}

# The positive counterpart, so a build layout that names module files
# differently cannot make expect_no_modules pass vacuously.
expect_modules() {
  local name=$1
  shift
  for module in "$@"; do
    [[ -n $(find "$TMP/$name/.build" -name "$module.swiftmodule" -print -quit) ]] ||
      fail "$name did not compile $module (or module files are not named $module.swiftmodule)"
  done
}

# --- 1. Petrel only, default traits --------------------------------------------
consumer consumer-petrel-only PetrelURLConsumer \
  '.package(url: "PETREL_URL", exact: "99.0.0"),'
expect_unpinned_unless_61 consumer-petrel-only swift-nio swift-nio-ssl hummingbird
"$SWIFT" build --package-path "$TMP/consumer-petrel-only" --scratch-path "$TMP/consumer-petrel-only/.build"
expect_no_modules consumer-petrel-only NIOCore NIOPosix NIOSSL Hummingbird
echo "ok: Petrel with default traits compiles no SwiftNIO or Hummingbird module"

# --- 2. OAuth server consumer, trait forgotten ---------------------------------
consumer consumer-no-trait PetrelOAuthServerTraitConsumer \
  '.package(url: "PETREL_URL", exact: "99.0.0"),'
expect_unpinned_unless_61 consumer-no-trait swift-nio swift-nio-ssl hummingbird
# expect_trait_error TRAIT: the build fails, and the error names TRAIT. One
# build per trait: a compiler that stops at the first failing file would hide
# the second message.
expect_trait_error() {
  local trait=$1 log=$TMP/consumer-no-trait-$1.log
  if "$SWIFT" build --package-path "$TMP/consumer-no-trait" --scratch-path "$TMP/consumer-no-trait/.build" >"$log" 2>&1; then
    fail "a consumer without $trait built code that needs it"
  fi
  grep -F "Enable the '$trait' package trait" "$log" >/dev/null || {
    cat "$log" >&2
    fail "the missing-trait error does not name $trait"
  }
}
# The fixture's main.swift uses PinnedNIOOAuthRemoteTransport.
expect_trait_error OAuthServerNIO
cat >"$TMP/consumer-no-trait/Sources/PetrelOAuthServerTraitConsumer/main.swift" <<'SWIFT'
import PetrelOAuthServerHummingbird

OAuthServerHummingbird.addRoutes(to: 0, server: 0)
SWIFT
expect_trait_error OAuthServerHummingbird
echo "ok: without the traits, the build errors name OAuthServerNIO and OAuthServerHummingbird"

# --- 3. OAuthServerNIO ----------------------------------------------------------
consumer consumer-nio PetrelOAuthServerTraitConsumer \
  '.package(url: "PETREL_URL", exact: "99.0.0", traits: ["OAuthServerNIO"]),'
pinned consumer-nio swift-nio && pinned consumer-nio swift-nio-ssl || fail "OAuthServerNIO did not resolve swift-nio and swift-nio-ssl"
expect_unpinned_unless_61 consumer-nio hummingbird
"$SWIFT" build --package-path "$TMP/consumer-nio" --scratch-path "$TMP/consumer-nio/.build"
expect_modules consumer-nio NIOCore NIOPosix NIOSSL
expect_no_modules consumer-nio Hummingbird
[[ $("$SWIFT" run --package-path "$TMP/consumer-nio" --scratch-path "$TMP/consumer-nio/.build" --skip-build) == "PinnedNIOOAuthRemoteTransport OK" ]] ||
  fail "the OAuthServerNIO consumer did not run"
echo "ok: OAuthServerNIO builds the pinned transport without Hummingbird"

# --- 4. OAuthServerHummingbird --------------------------------------------------
consumer consumer-hummingbird PetrelOAuthServerTraitConsumer \
  '.package(url: "PETREL_URL", exact: "99.0.0", traits: ["OAuthServerHummingbird"]),'
pinned consumer-hummingbird hummingbird || fail "OAuthServerHummingbird did not resolve hummingbird"
# The adapter's request context conforms to Hummingbird protocols, so it exists
# only when the trait really built the adapter.
cat >"$TMP/consumer-hummingbird/Sources/PetrelOAuthServerTraitConsumer/Adapter.swift" <<'SWIFT'
import PetrelOAuthServerHummingbird

func adapterContextType() -> Any.Type {
    OAuthServerRequestContext.self
}
SWIFT
"$SWIFT" build --package-path "$TMP/consumer-hummingbird" --scratch-path "$TMP/consumer-hummingbird/.build"
expect_modules consumer-hummingbird Hummingbird NIOCore NIOSSL
[[ $("$SWIFT" run --package-path "$TMP/consumer-hummingbird" --scratch-path "$TMP/consumer-hummingbird/.build" --skip-build) == "PinnedNIOOAuthRemoteTransport OK" ]] ||
  fail "the OAuthServerHummingbird consumer did not run"
echo "ok: OAuthServerHummingbird enables OAuthServerNIO"

echo "oauth-server traits contract passed"
