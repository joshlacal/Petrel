#!/bin/bash

# OAuth stress scenario runner for PetrelLoad
# This script invokes only scenarios implemented by the executable.

set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$ROOT/Scripts/activate-release-toolchain.sh"

NAMESPACE="${1:-com.petrel.test}"
ENDPOINT="${2:-app.bsky.actor.getProfile}"

echo "=== PetrelLoad OAuth Stress Scenarios ==="
echo "Namespace: $NAMESPACE"
echo "Test Endpoint: $ENDPOINT"
echo "Timestamp: $(date)"
echo ""

failures=0

# Run a scenario without eval and retain a failing exit status for the suite.
run_test() {
    local test_name="$1"
    shift

    echo "Running: $test_name"
    printf 'Command:'
    printf ' %q' "$@"
    echo
    echo "----------------------------------------"

    if "$@"; then
        echo "✓ $test_name completed successfully"
    else
        echo "✗ $test_name failed"
        failures=$((failures + 1))
    fi
    echo
}

# 1. Basic DPoP session check
run_test "DPoP Compliance Validation" \
    "$RELEASE_SWIFT" run --package-path "$ROOT" PetrelLoad \
    --namespace "$NAMESPACE" --endpoint "$ENDPOINT" --dpop-test compliance

# 2. DPoP Nonce Thrashing Test
run_test "DPoP Nonce Thrashing (50 requests, 10 concurrent)" \
    "$RELEASE_SWIFT" run --package-path "$ROOT" PetrelLoad \
    --namespace "$NAMESPACE" --endpoint "$ENDPOINT" \
    --oauth-test dpop_nonce_thrash --requests 50 --concurrency 10

# 3. Token refresh sequence
run_test "Token Refresh Sequence" \
    "$RELEASE_SWIFT" run --package-path "$ROOT" PetrelLoad \
    --namespace "$NAMESPACE" --endpoint "$ENDPOINT" \
    --oauth-test token_refresh_race

# 4. DPoP validation snapshot
run_test "DPoP Validation Snapshot" \
    "$RELEASE_SWIFT" run --package-path "$ROOT" PetrelLoad \
    --namespace "$NAMESPACE" --endpoint "$ENDPOINT" \
    --oauth-test dpop_validation

# 5. Nonce-handling load
run_test "DPoP Nonce Handling" \
    "$RELEASE_SWIFT" run --package-path "$ROOT" PetrelLoad \
    --namespace "$NAMESPACE" --endpoint "$ENDPOINT" \
    --dpop-test nonce-test

# 6. Explicit refresh check
run_test "DPoP Refresh Check" \
    "$RELEASE_SWIFT" run --package-path "$ROOT" PetrelLoad \
    --namespace "$NAMESPACE" --endpoint "$ENDPOINT" \
    --dpop-test refresh-test

# 7. Ambiguous refresh timeout handling
run_test "Ambiguous Refresh Timeout" \
    "$RELEASE_SWIFT" run --package-path "$ROOT" PetrelLoad \
    --namespace "$NAMESPACE" --endpoint "$ENDPOINT" \
    --simulate-ambiguous-timeout

# 8. Full implemented OAuth stress sequence
run_test "Complete OAuth Stress Suite (reduced scale)" \
    "$RELEASE_SWIFT" run --package-path "$ROOT" PetrelLoad \
    --namespace "$NAMESPACE" --endpoint "$ENDPOINT" \
    --oauth-stress --requests 100 --concurrency 10

echo "=== Test Suite Complete ==="
echo "Timestamp: $(date)"
echo ""
if (( failures > 0 )); then
    echo "$failures scenario(s) failed"
    exit 1
fi

echo "All implemented scenarios completed successfully"
