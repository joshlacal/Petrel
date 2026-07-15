#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
GATE=$ROOT/Scripts/verify-owned-warnings.sh
TMP=$(mktemp -d "${TMPDIR:-/tmp}/petrel-owned-warning-gate-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

expect_status() {
  local expected=$1
  shift

  set +e
  "$@" >"$TMP/stdout" 2>"$TMP/stderr"
  local actual=$?
  set -e

  if [[ $actual -ne $expected ]]; then
    printf 'expected status %s, got %s\n' "$expected" "$actual" >&2
    /bin/cat "$TMP/stdout" >&2
    /bin/cat "$TMP/stderr" >&2
    return 1
  fi
}

[[ -x $GATE ]] || {
  echo "owned-warning gate is missing or not executable: $GATE" >&2
  exit 1
}

expect_status 64 "$GATE"
expect_status 64 "$GATE" 'bad/label' -- /usr/bin/true
expect_status 23 "$GATE" command-failure -- /bin/bash -c 'exit 23'

for owned_path in \
  Package.swift \
  Sources/CLibSecretShim/shim.c \
  Sources/Petrel/Owned.swift \
  Sources/PetrelLoad/Owned.swift \
  Tests/PetrelTests/Owned.swift \
  Tests/PetrelLoadTests/Owned.swift \
  Tests/ReleaseScripts/Owned.swift; do
  # The inner shell expands its positional parameter, not this test process.
  # shellcheck disable=SC2016
  expect_status 1 "$GATE" owned-warning -- /bin/bash -c \
    'printf "%s:1:2: warning: package-owned warning\n" "$1"' _ "$owned_path"
done

# The inner shell expands its positional parameter, not this test process.
# shellcheck disable=SC2016
expect_status 1 "$GATE" absolute-manifest-warning -- /bin/bash -c \
  'printf "%s:1:2: warning: package-owned manifest warning\n" "$1"' _ \
  "$ROOT/Package.swift"

expect_status 1 "$GATE" pathless-package-warning -- /bin/bash -c \
  "printf \"warning: 'petrel': found 1 file(s) which are unhandled\\n\""

# The inner shell expands its positional parameter, not this test process.
# shellcheck disable=SC2016
expect_status 0 "$GATE" dependency-warning -- /bin/bash -c \
  'printf "%s:3:4: warning: dependency warning\n" "$1"' _ \
  "$ROOT/.build/checkouts/Dependency/Sources/Petrel/Dependency.swift"

expect_status 0 "$GATE" source-chatter -- /bin/bash -c \
  'printf "Compiling Sources/Petrel/Owned.swift with warning: text\n"'

expect_status 0 "$GATE" pkg-config-advisory -- /bin/bash -c \
  "printf \"warning: 'petrel': failed to retrieve search paths with pkg-config; maybe pkg-config is not installed\\n\""

FAILING_BIN=$TMP/failing-bin
/bin/mkdir -p "$FAILING_BIN"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'while IFS= read -r _; do :; done'
  printf '%s\n' 'exit 74'
} >"$FAILING_BIN/tee"
/bin/chmod +x "$FAILING_BIN/tee"

PATH="$FAILING_BIN:$PATH" expect_status 74 \
  "$GATE" tee-failure -- /bin/bash -c 'printf "complete output\n"'
PATH="$FAILING_BIN:$PATH" expect_status 23 \
  "$GATE" command-precedence -- /bin/bash -c 'printf "complete output\n"; exit 23'
