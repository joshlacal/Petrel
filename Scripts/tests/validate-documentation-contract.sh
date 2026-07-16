#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
VALIDATOR="$ROOT/Scripts/validate-documentation.sh"
EXTRACTOR="$ROOT/Scripts/extract-documentation-examples.sh"
README="$ROOT/README.md"
GUIDE="$ROOT/GETTING_STARTED.md"
GETTING_STARTED="$ROOT/Sources/Petrel/Petrel.docc/GettingStarted.md"
AUTHENTICATION="$ROOT/Sources/Petrel/Petrel.docc/Authentication.md"
RELEASE_NOTES="$ROOT/docs/releases/0.2.0.md"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/petrel-documentation-contract.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

[[ -x $VALIDATOR ]]
[[ -x $EXTRACTOR ]] || {
    echo "documentation example extractor is missing or not executable" >&2
    exit 1
}
/bin/bash -n "$VALIDATOR"
/bin/bash -n "$EXTRACTOR"

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
/usr/bin/grep -F 'Scripts/extract-documentation-examples.sh' "$VALIDATOR" >/dev/null
/usr/bin/grep -F 'README.md' "$VALIDATOR" >/dev/null
/usr/bin/grep -F 'GETTING_STARTED.md' "$VALIDATOR" >/dev/null
/usr/bin/grep -F 'readme-package-manifest.swift' "$VALIDATOR" >/dev/null
/usr/bin/grep -F 'readme-oauth.swift' "$VALIDATOR" >/dev/null
/usr/bin/grep -F 'readme-public-profile.swift' "$VALIDATOR" >/dev/null
/usr/bin/grep -F 'guide-package-manifest.swift' "$VALIDATOR" >/dev/null
/usr/bin/grep -F 'guide-public-profile.swift' "$VALIDATOR" >/dev/null
/usr/bin/grep -F 'guide-oauth.swift' "$VALIDATOR" >/dev/null
/usr/bin/grep -F 'compile-example: getting-started-basic' "$GETTING_STARTED" >/dev/null
/usr/bin/grep -F 'compile-example: package-manifest' "$GETTING_STARTED" >/dev/null
/usr/bin/grep -F 'compile-example: oauth-authentication' "$AUTHENTICATION" >/dev/null
/usr/bin/grep -F 'compile-example: oauth-callback' "$AUTHENTICATION" >/dev/null
/usr/bin/grep -F 'compile-example: readme-package-manifest' "$README" >/dev/null
/usr/bin/grep -F 'compile-example: readme-oauth' "$README" >/dev/null
/usr/bin/grep -F 'compile-example: readme-public-profile' "$README" >/dev/null
/usr/bin/grep -F 'compile-example: guide-package-manifest' "$GUIDE" >/dev/null
/usr/bin/grep -F 'compile-example: guide-public-profile' "$GUIDE" >/dev/null
/usr/bin/grep -F 'compile-example: guide-oauth' "$GUIDE" >/dev/null
# The backticks are literal Markdown in the required release-scope sentence.
# shellcheck disable=SC2016
/usr/bin/grep -F 'Kotlin publication and Kotlin/Swift parity are outside the `0.2.0` SPM release gate.' "$README" >/dev/null
/usr/bin/grep -F 'Kotlin' "$GUIDE" >/dev/null
/usr/bin/grep -F 'outside this SPM release gate' "$GUIDE" >/dev/null
/usr/bin/grep -F 'loginWithPassword' "$AUTHENTICATION" >/dev/null
/usr/bin/grep -F 'Prefer' "$AUTHENTICATION" >/dev/null
/usr/bin/grep -F 'OAuth' "$AUTHENTICATION" >/dev/null
/usr/bin/grep -F 'Kotlin publication and parity are outside this release gate.' "$RELEASE_NOTES" >/dev/null
/usr/bin/grep -F 'Pages deployment remains deferred' "$RELEASE_NOTES" >/dev/null
if /usr/bin/grep -F 'not exposed by the public API' "$AUTHENTICATION" >/dev/null; then
    echo "authentication documentation denies the public password API" >&2
    exit 1
fi
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

mkdir "$TMP/examples"
"$EXTRACTOR" "$TMP/examples" \
    "$README" \
    "$GUIDE" \
    "$GETTING_STARTED" \
    "$AUTHENTICATION"

expected_examples=$(printf '%s\n' \
    getting-started-basic.swift \
    guide-oauth.swift \
    guide-package-manifest.swift \
    guide-public-profile.swift \
    oauth-authentication.swift \
    oauth-callback.swift \
    package-manifest.swift \
    readme-oauth.swift \
    readme-package-manifest.swift \
    readme-public-profile.swift)
actual_examples=$(find "$TMP/examples" -type f -name '*.swift' -exec basename {} \; | LC_ALL=C sort)
[[ $actual_examples == "$expected_examples" ]] || {
    printf 'unexpected extracted example inventory\nexpected:\n%s\nactual:\n%s\n' \
        "$expected_examples" "$actual_examples" >&2
    exit 1
}

cp "$README" "$TMP/unmarked.md"
# The fenced Markdown is intentionally literal test data.
# shellcheck disable=SC2016
printf '\n```swift\nlet unmarked = true\n```\n' >> "$TMP/unmarked.md"
set +e
unmarked_output=$("$EXTRACTOR" "$TMP/unmarked-output" "$TMP/unmarked.md" 2>&1)
unmarked_status=$?
set -e
if [[ $unmarked_status -eq 0 || $unmarked_output != *"unmarked Swift fence"* ]]; then
    printf 'extractor must reject an unmarked Swift fence; status=%s output=%s\n' \
        "$unmarked_status" "$unmarked_output" >&2
    exit 1
fi

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
