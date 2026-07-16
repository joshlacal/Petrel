#!/bin/bash

# OAuth stress scenario runner for PetrelLoad
# This script invokes only scenarios implemented by the executable.

set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$ROOT/Scripts/activate-release-toolchain.sh"

if (( $# != 4 )); then
    echo "Usage: $0 <namespace> <endpoint> <client-id> <redirect-uri>" >&2
    exit 2
fi

NAMESPACE="$1"
ENDPOINT="$2"
CLIENT_ID="$3"
REDIRECT_URI="$4"

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

# 1. Basic OAuth session check
run_test "OAuth Session Check" \
    "$RELEASE_SWIFT" run --package-path "$ROOT" PetrelLoad \
    --namespace "$NAMESPACE" --endpoint "$ENDPOINT" \
    --client-id "$CLIENT_ID" --redirect-uri "$REDIRECT_URI" \
    --dpop-test session-check

# 2. Authenticated request load
run_test "Authenticated Request Load (50 requests, 10 concurrent)" \
    "$RELEASE_SWIFT" run --package-path "$ROOT" PetrelLoad \
    --namespace "$NAMESPACE" --endpoint "$ENDPOINT" \
    --client-id "$CLIENT_ID" --redirect-uri "$REDIRECT_URI" \
    --oauth-test authenticated-load --requests 50 --concurrency 10

# 3. Token refresh sequence
run_test "Token Refresh Sequence" \
    "$RELEASE_SWIFT" run --package-path "$ROOT" PetrelLoad \
    --namespace "$NAMESPACE" --endpoint "$ENDPOINT" \
    --client-id "$CLIENT_ID" --redirect-uri "$REDIRECT_URI" \
    --oauth-test refresh-sequence

# 4. OAuth session snapshot
run_test "OAuth Session Snapshot" \
    "$RELEASE_SWIFT" run --package-path "$ROOT" PetrelLoad \
    --namespace "$NAMESPACE" --endpoint "$ENDPOINT" \
    --client-id "$CLIENT_ID" --redirect-uri "$REDIRECT_URI" \
    --oauth-test session-snapshot

# 5. Fixed-size authenticated load
run_test "Fixed Authenticated Request Load" \
    "$RELEASE_SWIFT" run --package-path "$ROOT" PetrelLoad \
    --namespace "$NAMESPACE" --endpoint "$ENDPOINT" \
    --client-id "$CLIENT_ID" --redirect-uri "$REDIRECT_URI" \
    --dpop-test authenticated-load

# 6. Explicit refresh check
run_test "Token Refresh Check" \
    "$RELEASE_SWIFT" run --package-path "$ROOT" PetrelLoad \
    --namespace "$NAMESPACE" --endpoint "$ENDPOINT" \
    --client-id "$CLIENT_ID" --redirect-uri "$REDIRECT_URI" \
    --dpop-test refresh-check

# 7. Ambiguous refresh timeout handling
run_test "Ambiguous Refresh Timeout" \
    "$RELEASE_SWIFT" run --package-path "$ROOT" PetrelLoad \
    --namespace "$NAMESPACE" --endpoint "$ENDPOINT" \
    --client-id "$CLIENT_ID" --redirect-uri "$REDIRECT_URI" \
    --simulate-ambiguous-timeout

# 8. Authenticated load sequence
run_test "Authenticated Load Sequence (reduced scale)" \
    "$RELEASE_SWIFT" run --package-path "$ROOT" PetrelLoad \
    --namespace "$NAMESPACE" --endpoint "$ENDPOINT" \
    --client-id "$CLIENT_ID" --redirect-uri "$REDIRECT_URI" \
    --oauth-stress --requests 100 --concurrency 10

echo "=== Test Suite Complete ==="
echo "Timestamp: $(date)"
echo ""
if (( failures > 0 )); then
    echo "$failures scenario(s) failed"
    exit 1
fi

echo "All implemented scenarios completed successfully"
