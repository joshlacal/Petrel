#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# The release activator path is derived from this script at runtime.
# shellcheck disable=SC1091
source "$ROOT/Scripts/activate-release-toolchain.sh"

scratch_path=${PETREL_DOCC_SCRATCH_PATH:-"$ROOT/.build/release-documentation"}

validate_documentation() {
    "$RELEASE_SWIFT" package "$@" \
        --scratch-path "$scratch_path" \
        generate-documentation \
        --target Petrel \
        --warnings-as-errors
}

typecheck_documentation_examples() {
    local example_dir example_bin_path example_count example macos_sdk release_swiftc target
    example_dir=$(mktemp -d "${TMPDIR:-/tmp}/petrel-documentation-examples.XXXXXX")
    trap 'rm -rf "$example_dir"' RETURN

    /usr/bin/awk -v output_dir="$example_dir" '
            function fail(message) {
                print FILENAME ": " message > "/dev/stderr"
                failed = 1
                exit 1
            }

            /^<!-- compile-example: [a-z0-9-]+ -->$/ {
                if (waiting_for_fence || in_example) {
                    fail("nested compile-example marker")
                }
                name = $0
                sub(/^<!-- compile-example: /, "", name)
                sub(/ -->$/, "", name)
                if (seen[name]) {
                    fail("duplicate compile-example marker: " name)
                }
                seen[name] = 1
                output = output_dir "/" name ".swift"
                waiting_for_fence = 1
                next
            }

            waiting_for_fence && $0 == "```swift" {
                waiting_for_fence = 0
                in_example = 1
                example_lines = 0
                next
            }

            waiting_for_fence && $0 == "" { next }
            waiting_for_fence { fail("compile-example marker must precede a Swift fence") }

            in_example && $0 == "```" {
                if (example_lines == 0) {
                    fail("empty compile-example fence: " name)
                }
                close(output)
                in_example = 0
                next
            }

            in_example {
                print > output
                example_lines += 1
            }

            END {
                if (!failed && (waiting_for_fence || in_example)) {
                    fail("unterminated compile-example fence")
                }
            }
        ' \
        "$ROOT/Sources/Petrel/Petrel.docc/GettingStarted.md" \
        "$ROOT/Sources/Petrel/Petrel.docc/Authentication.md"

    for example in \
        getting-started-basic.swift \
        oauth-authentication.swift \
        oauth-callback.swift \
        package-manifest.swift; do
        [[ -s $example_dir/$example ]] || {
            echo "missing documentation compile example: $example" >&2
            return 1
        }
    done
    example_count=$(find "$example_dir" -type f -name '*.swift' | wc -l | tr -d '[:space:]')
    [[ $example_count == 4 ]] || {
        echo "unexpected documentation compile example count: $example_count" >&2
        return 1
    }

    "$RELEASE_SWIFT" build \
        --build-system native \
        --scratch-path "$scratch_path" \
        --target Petrel
    example_bin_path=$(
        "$RELEASE_SWIFT" build \
            --build-system native \
            --scratch-path "$scratch_path" \
            --show-bin-path
    )

    release_swiftc="$(dirname "$RELEASE_SWIFT")/swiftc"
    [[ -x $release_swiftc ]] || {
        echo "selected release swiftc is not executable: $release_swiftc" >&2
        return 1
    }
    macos_sdk=$("$RELEASE_XCRUN" --sdk macosx --show-sdk-path)
    target="$(uname -m)-apple-macosx15.0"

    "$release_swiftc" \
        -typecheck \
        -swift-version 6 \
        -package-description-version 6.0.0 \
        -warnings-as-errors \
        -sdk "$macos_sdk" \
        -target "$target" \
        -I "$(dirname "$RELEASE_SWIFT")/../lib/swift/pm/ManifestAPI" \
        "$example_dir/package-manifest.swift"

    for example in \
        "$example_dir/getting-started-basic.swift" \
        "$example_dir/oauth-authentication.swift" \
        "$example_dir/oauth-callback.swift"; do
        "$release_swiftc" \
            -typecheck \
            -parse-as-library \
            -swift-version 6 \
            -warnings-as-errors \
            -sdk "$macos_sdk" \
            -target "$target" \
            -I "$example_bin_path/Modules" \
            -Xcc -fmodule-map-file="$example_bin_path/CAsyncDNSResolver.build/module.modulemap" \
            -Xcc -fmodule-map-file="$scratch_path/checkouts/zlib/Sources/Zlib/module.modulemap" \
            -Xcc -fmodule-map-file="$example_bin_path/secp256k1_bindings.build/module.modulemap" \
            -Xcc -I \
            -Xcc "$scratch_path/checkouts/swift-async-dns-resolver/Sources/CAsyncDNSResolver/include" \
            "$example"
    done
}

# SwiftPM #10285 makes Swift 6.4's default SwiftBuild path misclassify .docc
# catalogs. The native path keeps the catalog discoverable until the upstream
# fix lands: https://github.com/swiftlang/swift-package-manager/issues/10285
if [[ ${RELEASE_TOOLCHAIN_LANE:-} == local-validation &&
      ${RELEASE_SWIFT_VERSION:-} == 6.4 &&
      ${RELEASE_XCODE_VERSION:-} == 27.0 &&
      ${RELEASE_XCODE_BUILD:-} == 27A5218g ]]; then
    validate_documentation --build-system native
else
    validate_documentation
fi

typecheck_documentation_examples
