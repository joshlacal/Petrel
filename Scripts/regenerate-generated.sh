#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

require_executable() {
  local name=$1
  local value=${!name:-}
  [[ -n $value && $value == /* && -x $value ]] || {
    echo "$name must name an absolute executable from the activated release toolchain" >&2
    exit 1
  }
}

require_absolute_path() {
  local name=$1
  local value=${!name:-}
  [[ -n $value && $value == /* ]] || {
    echo "$name must be an absolute path from the activated release toolchain" >&2
    exit 1
  }
}

require_executable PETREL_PYTHON
require_executable RELEASE_MINT
require_executable RELEASE_SWIFT
require_executable RELEASE_XCODEBUILD
require_executable RELEASE_XCRUN
require_absolute_path DEVELOPER_DIR
require_absolute_path MINT_PATH
require_absolute_path MINT_LINK_PATH

[[ $(command -v swift) == "$RELEASE_SWIFT" ]] || {
  echo "activated RELEASE_SWIFT is not first on PATH" >&2
  exit 1
}

if [[ -e $ROOT/.jj ]]; then
  if ! checkout_summary=$(jj diff --summary); then
    echo "unable to verify the local jj checkout" >&2
    exit 1
  fi
  test -z "$checkout_summary"
elif [[ -e $ROOT/.git ]]; then
  if ! checkout_summary=$(git status --porcelain --untracked-files=all); then
    echo "unable to verify the ephemeral Git-only checkout" >&2
    exit 1
  fi
  test -z "$checkout_summary"
else
  echo "regeneration requires a local jj checkout or ephemeral Git-only checkout" >&2
  exit 1
fi

"$PETREL_PYTHON" run.py \
  --manifest generator/manifests/petrel-core.json \
  --language swift
"$RELEASE_MINT" run --executable swiftformat nicklockwood/SwiftFormat@0.61.1 \
  Sources/Petrel/Generated
