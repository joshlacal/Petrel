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
    local actual_examples example_dir example_bin_path example expected_examples macos_sdk release_swiftc target
    example_dir=$(mktemp -d "${TMPDIR:-/tmp}/petrel-documentation-examples.XXXXXX")
    trap 'rm -rf "$example_dir"' RETURN

    "$ROOT/Scripts/extract-documentation-examples.sh" "$example_dir" \
        "$ROOT/README.md" \
        "$ROOT/GETTING_STARTED.md" \
        "$ROOT/Sources/Petrel/Petrel.docc/GettingStarted.md" \
        "$ROOT/Sources/Petrel/Petrel.docc/Authentication.md"

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
    actual_examples=$(find "$example_dir" -type f -name '*.swift' -exec basename {} \; | LC_ALL=C sort)
    [[ $actual_examples == "$expected_examples" ]] || {
        printf 'unexpected documentation compile example inventory\nexpected:\n%s\nactual:\n%s\n' \
            "$expected_examples" "$actual_examples" >&2
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

    for example in "$example_dir"/*.swift; do
        case $(basename "$example") in
            *package-manifest.swift)
                "$release_swiftc" \
                    -typecheck \
                    -swift-version 6 \
                    -package-description-version 6.0.0 \
                    -warnings-as-errors \
                    -sdk "$macos_sdk" \
                    -target "$target" \
                    -I "$(dirname "$RELEASE_SWIFT")/../lib/swift/pm/ManifestAPI" \
                    "$example"
                ;;
            *)
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
                ;;
        esac
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
