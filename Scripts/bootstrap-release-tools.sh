#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TOOLS_ROOT="$ROOT/.build/release-tools"
DOWNLOAD_ROOT="$TOOLS_ROOT/downloads"
MINT_ARCHIVE="$DOWNLOAD_ROOT/mint-0.18.0.zip"
MINT_URL=https://github.com/yonaskolb/Mint/releases/download/0.18.0/mint.zip
MINT_SHA256=ce44b0fc4ef3bc854ea43b2d2d3f96502d52231c0e0849ec212815121955f5ef
MINT_REPOSITORY=https://github.com/yonaskolb/Mint.git
MINT_TAG=refs/tags/0.18.0
MINT_COMMIT=7bc67a0b925b949c8becc327bc08f56eeadc0051
SWIFTFORMAT_REPOSITORY=https://github.com/nicklockwood/SwiftFormat.git
SWIFTFORMAT_TAG=refs/tags/0.61.1
SWIFTFORMAT_COMMIT=a5fa7a6a57abeb834df1b3fa43ea9133137d5ade
SWIFTFORMAT_SPEC=nicklockwood/SwiftFormat@0.61.1
SWIFTFORMAT_STAMP="$TOOLS_ROOT/swiftformat-0.61.1.commit"

[[ -n ${RELEASE_SWIFT:-} && -x $RELEASE_SWIFT ]] || {
  echo "activate Scripts/activate-release-toolchain.sh before bootstrapping release tools" >&2
  exit 1
}
[[ $(command -v swift) == "$RELEASE_SWIFT" ]] || {
  echo "activated RELEASE_SWIFT is not first on PATH" >&2
  exit 1
}

resolve_tag() {
  local repository=$1
  local tag=$2
  local expected=$3
  local output actual resolved_ref line_count
  output=$(/usr/bin/git ls-remote "$repository" "$tag")
  line_count=$(printf '%s\n' "$output" | /usr/bin/awk 'NF { count += 1 } END { print count + 0 }')
  [[ $line_count == 1 ]] || {
    echo "expected exactly one resolution for $repository $tag" >&2
    return 1
  }
  read -r actual resolved_ref <<<"$output"
  [[ $resolved_ref == "$tag" && $actual == "$expected" ]] || {
    echo "tag provenance mismatch for $repository $tag" >&2
    return 1
  }
}

resolve_tag "$MINT_REPOSITORY" "$MINT_TAG" "$MINT_COMMIT"
mkdir -p "$DOWNLOAD_ROOT" "$TOOLS_ROOT"
if [[ -e $MINT_ARCHIVE ]]; then
  [[ -f $MINT_ARCHIVE ]] || {
    echo "Mint archive path is not a regular file: $MINT_ARCHIVE" >&2
    exit 1
  }
else
  download="$MINT_ARCHIVE.download.$$.${RANDOM}"
  /usr/bin/curl -fL --proto '=https' --tlsv1.2 -o "$download" "$MINT_URL"
  actual_download_sha=$(/usr/bin/shasum -a 256 "$download" | /usr/bin/awk '{print $1}')
  [[ $actual_download_sha == "$MINT_SHA256" ]] || {
    mv "$download" "$download.bad-sha256"
    echo "Mint archive SHA-256 mismatch" >&2
    exit 1
  }
  mv "$download" "$MINT_ARCHIVE"
fi
actual_archive_sha=$(/usr/bin/shasum -a 256 "$MINT_ARCHIVE" | /usr/bin/awk '{print $1}')
[[ $actual_archive_sha == "$MINT_SHA256" ]] || {
  echo "cached Mint archive SHA-256 mismatch" >&2
  exit 1
}

RELEASE_MINT="$TOOLS_ROOT/mint"
MINT_PATH="$TOOLS_ROOT/mint-packages"
MINT_LINK_PATH="$TOOLS_ROOT/mint-links"
export RELEASE_MINT MINT_PATH MINT_LINK_PATH
mkdir -p "$MINT_PATH" "$MINT_LINK_PATH"

if [[ -e $RELEASE_MINT ]]; then
  [[ -x $RELEASE_MINT ]] || {
    echo "existing release Mint is not executable" >&2
    exit 1
  }
else
  extraction="$TOOLS_ROOT/mint-extraction.$$.${RANDOM}"
  mkdir -p "$extraction"
  /usr/bin/unzip -qq "$MINT_ARCHIVE" -d "$extraction"
  [[ -f $extraction/mint ]] || {
    echo "official Mint archive did not contain the mint binary" >&2
    exit 1
  }
  chmod 0755 "$extraction/mint"
  mv "$extraction/mint" "$RELEASE_MINT"
  mv "$extraction" "${TMPDIR:-/tmp}/petrel-mint-extraction.$$.${RANDOM}"
fi
[[ $("$RELEASE_MINT" --version | /usr/bin/tr -d '\r\n') == 'Version: 0.18.0' ]] || {
  echo "release Mint is not exactly Version: 0.18.0" >&2
  exit 1
}

resolve_tag "$SWIFTFORMAT_REPOSITORY" "$SWIFTFORMAT_TAG" "$SWIFTFORMAT_COMMIT"
if [[ -e $SWIFTFORMAT_STAMP ]]; then
  [[ -f $SWIFTFORMAT_STAMP ]] || {
    echo "SwiftFormat provenance stamp is not a regular file" >&2
    exit 1
  }
  [[ $(<"$SWIFTFORMAT_STAMP") == "$SWIFTFORMAT_COMMIT" ]] || {
    echo "SwiftFormat provenance stamp does not match the pinned tag commit" >&2
    exit 1
  }
fi

"$RELEASE_MINT" install "$SWIFTFORMAT_SPEC" --no-link
swiftformat_version=$(
  "$RELEASE_MINT" run --executable swiftformat "$SWIFTFORMAT_SPEC" --version |
    /usr/bin/tr -d '\r\n'
)
[[ $swiftformat_version == 0.61.1 ]] || {
  echo "installed SwiftFormat is not exactly 0.61.1" >&2
  exit 1
}
if [[ ! -e $SWIFTFORMAT_STAMP ]]; then
  printf '%s\n' "$SWIFTFORMAT_COMMIT" >"$SWIFTFORMAT_STAMP"
fi
