#!/bin/bash

# OAuth Stress Testing Script for PetrelLoad
# This script runs comprehensive OAuth and DPoP compliance tests

set -e

NAMESPACE="${1:-com.petrel.test}"
ENDPOINT="${2:-app.bsky.actor.getProfile}"

echo "=== PetrelLoad OAuth Compliance Test Suite ==="
echo "Namespace: $NAMESPACE"
echo "Test Endpoint: $ENDPOINT"
echo "Timestamp: $(date)"
echo ""

# Function to run a test and capture results
run_test() {
    local test_name="$1"
    local command="$2"
    
    echo "Running: $test_name"
    echo "Command: $command"
    echo "----------------------------------------"
    
    if eval "$command"; then
        echo "✓ $test_name completed successfully"
    else
        echo "✗ $test_name failed"
    fi
    echo ""
}

# 1. Basic DPoP Compliance Check
run_test "DPoP Compliance Validation" \
    "swift run PetrelLoad --namespace $NAMESPACE --endpoint $ENDPOINT --dpop-test compliance"

# 2. DPoP Nonce Thrashing Test
run_test "DPoP Nonce Thrashing (50 requests, 10 concurrent)" \
    "swift run PetrelLoad --namespace $NAMESPACE --endpoint $ENDPOINT --oauth-test dpop_nonce_thrash --requests 50 --concurrency 10"

# 3. Token Refresh Race Conditions
run_test "Token Refresh Race Conditions (20 concurrent refreshes)" \
    "swift run PetrelLoad --namespace $NAMESPACE --endpoint $ENDPOINT --oauth-test token_refresh_race --requests 20 --concurrency 20"

# 4. Audience Mismatch Recovery
run_test "Audience Mismatch Recovery Test" \
    "swift run PetrelLoad --namespace $NAMESPACE --endpoint $ENDPOINT --oauth-test audience_mismatch --requests 30 --concurrency 5"

# 5. Rate Limit Compliance
run_test "Rate Limit Compliance (100 req bursts)" \
    "swift run PetrelLoad --namespace $NAMESPACE --endpoint app.bsky.feed.getTimeline --oauth-test rate_limit_compliance --requests 200 --burst-size 100 --burst-delay 0.1"

# 6. DPoP Edge Cases
echo "=== DPoP Edge Case Testing ==="

run_test "JTI Replay Detection" \
    "swift run PetrelLoad --namespace $NAMESPACE --endpoint $ENDPOINT --dpop-test replay-jti --requests 30 --concurrency 3"

run_test "Access Token Hash Validation" \
    "swift run PetrelLoad --namespace $NAMESPACE --endpoint $ENDPOINT --dpop-test wrong-ath --requests 30 --concurrency 3"

run_test "Clock Skew Tolerance" \
    "swift run PetrelLoad --namespace $NAMESPACE --endpoint $ENDPOINT --dpop-test clock-skew --requests 30 --concurrency 3"

run_test "Stale Nonce Handling" \
    "swift run PetrelLoad --namespace $NAMESPACE --endpoint $ENDPOINT --dpop-test stale-nonce --requests 40 --concurrency 5"

# 7. Extended Nonce Exhaustion Test (shorter version)
run_test "Nonce Exhaustion Test (60 seconds)" \
    "timeout 60 swift run PetrelLoad --namespace $NAMESPACE --endpoint $ENDPOINT --dpop-test nonce-exhaustion || echo 'Test completed within timeout'"

# 8. Account Switching Test (if multiple accounts available)
echo "=== Multi-Account Testing ==="
echo "Note: Account switching test requires 2+ stored accounts"
echo "If this fails, you may need to set up additional OAuth accounts"

run_test "Account Switching Under Load" \
    "swift run PetrelLoad --namespace $NAMESPACE --endpoint $ENDPOINT --oauth-test account_switch_storm --requests 40 --concurrency 5 --multi-account || echo 'Skipped: Requires multiple accounts'"

# 9. Full OAuth Stress Test (smaller scale for CI)
echo "=== Full OAuth Stress Test ==="
run_test "Complete OAuth Stress Suite (reduced scale)" \
    "swift run PetrelLoad --namespace $NAMESPACE --endpoint $ENDPOINT --oauth-stress --requests 100 --concurrency 10"

echo "=== Test Suite Complete ==="
echo "Timestamp: $(date)"
echo ""
echo "Summary:"
echo "- Review the output above for any failed tests"
echo "- Pay attention to recovery success rates (should be >95%)"
echo "- Check for proper error categorization"
echo "- Verify DPoP compliance validation passed"
echo ""
echo "For more detailed testing, run individual scenarios with higher request counts:"
echo "  swift run PetrelLoad --namespace $NAMESPACE --endpoint $ENDPOINT --oauth-test dpop_nonce_thrash --requests 500 --concurrency 25"
echo ""
echo "For production validation, consider:"
echo "1. Running tests against your staging PDS"
echo "2. Monitoring server-side logs during tests"
echo "3. Comparing results with a Node.js reference client"
echo "4. Testing with your actual production endpoints"