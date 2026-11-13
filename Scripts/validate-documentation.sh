#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# The release activator path is derived from this script at runtime.
# shellcheck disable=SC1091
source "$ROOT/Scripts/activate-release-toolchain.sh"

scratch_path=${PETREL_DOCC_SCRATCH_PATH:-"$ROOT/.build/release-documentation"}
# Examples are compiled against a build with every package trait enabled, so
# snippets for trait-gated products (PetrelOAuthServerHummingbird) are checked
# against the real API rather than the unavailable stubs. It uses its own
# scratch path so the default-trait DocC build is not invalidated.
examples_scratch_path=${PETREL_DOCC_EXAMPLES_SCRATCH_PATH:-"$ROOT/.build/release-documentation-examples"}

# Every library target that ships a DocC catalog. The documentation build
# fails on any warning in any of them.
DOCUMENTED_TARGETS=(
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

# Library targets the examples may import.
EXAMPLE_TARGETS=(
    "${DOCUMENTED_TARGETS[@]}"
    PetrelOAuthServerNIO
    PetrelOAuthServerHummingbird
)

validate_documentation() {
    local target_args=() documented_target
    for documented_target in "${DOCUMENTED_TARGETS[@]}"; do
        target_args+=(--target "$documented_target")
    done

    "$RELEASE_SWIFT" package "$@" \
        --scratch-path "$scratch_path" \
        generate-documentation \
        "${target_args[@]}" \
        --warnings-as-errors
}

# Public guides whose Swift fences must all compile: the root guides, the
# Spaces guide, and every article in every DocC catalog. The extractor rejects any Swift fence
# that is not preceded by a compile-example marker, so nothing is skipped.
documentation_sources() {
    printf '%s\n' "$ROOT/README.md" "$ROOT/GETTING_STARTED.md" "$ROOT/docs/Spaces.md"
    find "$ROOT/Sources" -path '*/*.docc/*' -type f -name '*.md' | LC_ALL=C sort
}

typecheck_documentation_examples() {
    local example_dir example_bin_path example macos_sdk release_swiftc target
    local example_count fence_count build_target
    local sources=() source_file
    example_dir=$(mktemp -d "${TMPDIR:-/tmp}/petrel-documentation-examples.XXXXXX")
    trap 'rm -rf "$example_dir"' RETURN

    while IFS= read -r source_file; do
        sources+=("$source_file")
    done < <(documentation_sources)

    "$ROOT/Scripts/extract-documentation-examples.sh" "$example_dir" "${sources[@]}"

    # Inventory: one compiled example per Swift fence, and the launch examples
    # the release contract names must be present.
    fence_count=$(cat "${sources[@]}" | /usr/bin/grep -c '^```swift$' || true)
    example_count=$(find "$example_dir" -type f -name '*.swift' | /usr/bin/wc -l | /usr/bin/tr -d ' ')
    [[ $example_count == "$fence_count" ]] || {
        printf 'documentation example inventory mismatch: %s Swift fences, %s extracted examples\n' \
            "$fence_count" "$example_count" >&2
        return 1
    }
    for example in \
        readme-package-manifest.swift \
        readme-public-profile.swift \
        readme-oauth.swift \
        guide-package-manifest.swift \
        guide-public-profile.swift \
        guide-oauth.swift \
        getting-started-basic.swift \
        package-manifest.swift \
        oauth-authentication.swift \
        oauth-callback.swift; do
        [[ -f "$example_dir/$example" ]] || {
            echo "required documentation example is missing: $example" >&2
            return 1
        }
    done

    for build_target in "${EXAMPLE_TARGETS[@]}"; do
        "$RELEASE_SWIFT" build \
            --build-system native \
            --scratch-path "$examples_scratch_path" \
            --enable-all-traits \
            --target "$build_target"
    done
    example_bin_path=$(
        "$RELEASE_SWIFT" build \
            --build-system native \
            --scratch-path "$examples_scratch_path" \
            --enable-all-traits \
            --show-bin-path
    )

    release_swiftc="$(dirname "$RELEASE_SWIFT")/swiftc"
    [[ -x $release_swiftc ]] || {
        echo "selected release swiftc is not executable: $release_swiftc" >&2
        return 1
    }
    macos_sdk=$("$RELEASE_XCRUN" --sdk macosx --show-sdk-path)
    target="$(uname -m)-apple-macosx15.0"

    # C modules built for the examples (BLAKE3, secp256k1, DNS resolver, NIO,
    # BoringSSL, zstd, ...). Each generated module map is passed explicitly, and each
    # checkout's public include and module-map directories are searchable.
    local cc_args=() module_map include_dir
    # Swift 6.1 also writes Objective-C interop module maps for Swift targets
    # (`<Target>-Swift.h`), including host-tool copies under `*-tool.build`;
    # loading those defines the same module twice, so only C module maps are
    # passed.
    while IFS= read -r module_map; do
        /usr/bin/grep -q -- '-Swift\.h"' "$module_map" && continue
        cc_args+=(-Xcc "-fmodule-map-file=$module_map")
    done < <(find "$example_bin_path" -maxdepth 2 -path '*.build/module.modulemap' -not -path '*-tool.build/*' | LC_ALL=C sort)
    while IFS= read -r include_dir; do
        cc_args+=(-Xcc -I -Xcc "$include_dir")
    done < <(
        {
            find "$examples_scratch_path/checkouts" -type d -path '*/Sources/*/include'
            # Packages such as zstd ship a hand-written module map outside include/.
            find "$examples_scratch_path/checkouts" -name module.modulemap \
                -not -path '*/Tests/*' -not -path '*/Benchmarks/*' -exec dirname {} \;
        } | LC_ALL=C sort -u
    )

    local failures=0
    for example in "$example_dir"/*.swift; do
        case $(basename "$example") in
            *package-manifest.swift)
                "$release_swiftc" \
                    -typecheck \
                    -swift-version 6 \
                    -package-description-version 6.1.0 \
                    -warnings-as-errors \
                    -sdk "$macos_sdk" \
                    -target "$target" \
                    -I "$(dirname "$RELEASE_SWIFT")/../lib/swift/pm/ManifestAPI" \
                    "$example" || {
                    echo "documentation example failed to compile: $(basename "$example")" >&2
                    failures=$((failures + 1))
                }
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
                    "${cc_args[@]}" \
                    "$example" || {
                    echo "documentation example failed to compile: $(basename "$example")" >&2
                    failures=$((failures + 1))
                }
                ;;
        esac
    done
    [[ $failures -eq 0 ]] || {
        echo "$failures documentation example(s) failed to compile" >&2
        return 1
    }
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
