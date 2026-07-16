#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
VALIDATOR="$ROOT/Scripts/validate-documentation.sh"
GETTING_STARTED="$ROOT/Sources/Petrel/Petrel.docc/GettingStarted.md"
AUTHENTICATION="$ROOT/Sources/Petrel/Petrel.docc/Authentication.md"

[[ -x $VALIDATOR ]]
/bin/bash -n "$VALIDATOR"

/usr/bin/grep -F 'set -euo pipefail' "$VALIDATOR" >/dev/null
# The following patterns intentionally assert literal shell expressions.
# shellcheck disable=SC2016
/usr/bin/grep -F 'source "$ROOT/Scripts/activate-release-toolchain.sh"' "$VALIDATOR" >/dev/null
# shellcheck disable=SC2016
/usr/bin/grep -F '"$RELEASE_SWIFT" package' "$VALIDATOR" >/dev/null
/usr/bin/grep -F -- '--target Petrel' "$VALIDATOR" >/dev/null
/usr/bin/grep -F -- '--warnings-as-errors' "$VALIDATOR" >/dev/null
/usr/bin/grep -F 'RELEASE_TOOLCHAIN_LANE:-' "$VALIDATOR" >/dev/null
/usr/bin/grep -F 'RELEASE_SWIFT_VERSION:-' "$VALIDATOR" >/dev/null
/usr/bin/grep -F 'RELEASE_XCODE_VERSION:-' "$VALIDATOR" >/dev/null
/usr/bin/grep -F 'RELEASE_XCODE_BUILD:-' "$VALIDATOR" >/dev/null
/usr/bin/grep -F -- '--build-system native' "$VALIDATOR" >/dev/null
/usr/bin/grep -F 'swiftlang/swift-package-manager/issues/10285' "$VALIDATOR" >/dev/null
/usr/bin/grep -F 'compile-example: getting-started-basic' "$GETTING_STARTED" >/dev/null
/usr/bin/grep -F 'compile-example: package-manifest' "$GETTING_STARTED" >/dev/null
/usr/bin/grep -F 'compile-example: oauth-authentication' "$AUTHENTICATION" >/dev/null
/usr/bin/grep -F 'compile-example: oauth-callback' "$AUTHENTICATION" >/dev/null
/usr/bin/grep -F -- '-typecheck' "$VALIDATOR" >/dev/null
/usr/bin/grep -F -- '-parse-as-library' "$VALIDATOR" >/dev/null
/usr/bin/grep -F -- '-warnings-as-errors' "$VALIDATOR" >/dev/null
# shellcheck disable=SC2016
/usr/bin/grep -F '$(dirname "$RELEASE_SWIFT")/swiftc' "$VALIDATOR" >/dev/null
# shellcheck disable=SC2016
/usr/bin/grep -F -- '-sdk "$macos_sdk"' "$VALIDATOR" >/dev/null
# shellcheck disable=SC2016
/usr/bin/grep -F -- '-target "$target"' "$VALIDATOR" >/dev/null
/usr/bin/grep -F 'getting-started-basic.swift' "$VALIDATOR" >/dev/null
/usr/bin/grep -F 'package-manifest.swift' "$VALIDATOR" >/dev/null
/usr/bin/grep -F 'oauth-authentication.swift' "$VALIDATOR" >/dev/null
/usr/bin/grep -F 'oauth-callback.swift' "$VALIDATOR" >/dev/null

if /usr/bin/grep -Eq '(^|[[:space:]])swift[[:space:]]+package' "$VALIDATOR"; then
    echo "documentation validator must not resolve ambient Swift" >&2
    exit 1
fi

if /usr/bin/grep -Eq '(exclude|resources|rm|mv).*[.]docc|Package[.]swift' "$VALIDATOR"; then
    echo "documentation validator must preserve the DocC catalog" >&2
    exit 1
fi

if /usr/bin/env -i PATH=/usr/bin:/bin /bin/bash "$VALIDATOR" >/dev/null 2>&1; then
    echo "documentation validator must fail closed without a release tuple" >&2
    exit 1
fi
