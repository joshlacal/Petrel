# PetrelLoad OAuth Stress Testing Suite

A comprehensive stress testing tool for OAuth, DPoP, and authentication edge cases in the Petrel ATProto Swift library.

## Features

### Basic Load Testing
Standard HTTP load testing with authentication:
```bash
PetrelLoad --namespace com.example.app --endpoint app.bsky.feed.getTimeline --requests 500 --concurrency 25
```

### OAuth Stress Testing Suite
Run all OAuth stress scenarios:
```bash
PetrelLoad --namespace com.example.app --endpoint app.bsky.actor.getProfile --oauth-stress
```

### Individual OAuth Test Scenarios

#### DPoP Nonce Thrashing
Tests concurrent DPoP nonce rotation and recovery:
```bash
PetrelLoad --namespace com.example.app --endpoint app.bsky.actor.getProfile --oauth-test dpop_nonce_thrash --requests 200 --concurrency 20
```

#### Token Refresh Race Conditions
Tests concurrent token refresh scenarios:
```bash
PetrelLoad --namespace com.example.app --endpoint app.bsky.actor.getProfile --oauth-test token_refresh_race --concurrency 15
```

#### Account Switching Under Load
Tests rapid account switching with concurrent requests (requires 2+ stored accounts):
```bash
PetrelLoad --namespace com.example.app --endpoint app.bsky.actor.getProfile --oauth-test account_switch_storm --multi-account
```

#### Audience Mismatch Recovery
Tests recovery from audience/resource indicator mismatches:
```bash
PetrelLoad --namespace com.example.app --endpoint app.bsky.actor.getProfile --oauth-test audience_mismatch
```

#### Rate Limit Compliance
Tests burst behavior and rate limit handling:
```bash
PetrelLoad --namespace com.example.app --endpoint app.bsky.feed.getTimeline --oauth-test rate_limit_compliance --burst-size 100 --burst-delay 0.05
```

### DPoP-Specific Testing

#### Compliance Validation
Basic DPoP implementation compliance check:
```bash
PetrelLoad --namespace com.example.app --endpoint app.bsky.actor.getProfile --dpop-test compliance
```

#### Nonce Exhaustion Test
Long-running test to trigger nonce rotations:
```bash
PetrelLoad --namespace com.example.app --endpoint app.bsky.actor.getProfile --dpop-test nonce-exhaustion
```

#### Specific DPoP Edge Cases
Test individual DPoP edge cases:
```bash
# JTI replay detection
PetrelLoad --namespace com.example.app --endpoint app.bsky.actor.getProfile --dpop-test replay-jti

# Access token hash validation
PetrelLoad --namespace com.example.app --endpoint app.bsky.actor.getProfile --dpop-test wrong-ath

# Clock skew tolerance
PetrelLoad --namespace com.example.app --endpoint app.bsky.actor.getProfile --dpop-test clock-skew

# Stale nonce handling
PetrelLoad --namespace com.example.app --endpoint app.bsky.actor.getProfile --dpop-test stale-nonce

# Malformed proof rejection
PetrelLoad --namespace com.example.app --endpoint app.bsky.actor.getProfile --dpop-test malformed-proof
```

## Test Scenarios Explained

### DPoP Nonce Thrashing (`dpop_nonce_thrash`)
- Fires concurrent requests to force multiple `use_dpop_nonce` errors
- Tests nonce rotation and recovery mechanisms
- Measures recovery time from nonce mismatches
- **Key Metrics**: Nonce rotations, recovery success rate, latency distribution

### Token Refresh Race (`token_refresh_race`)
- Triggers concurrent token refresh attempts
- Tests thread safety of refresh coordination
- Validates refresh token rotation behavior
- **Key Metrics**: Refresh attempts, success rate, race condition detection

### Account Switch Storm (`account_switch_storm`)
- Rapidly switches between stored accounts during load
- Tests DPoP key isolation per account
- Validates authentication provider updates
- **Key Metrics**: Account switches, authentication failures, isolation effectiveness

### Audience Mismatch (`audience_mismatch`)
- Tests requests to different PDS origins with same token
- Validates `invalid_audience` error recovery
- Tests audience override mechanisms
- **Key Metrics**: Audience errors, recovery time, cross-origin behavior

### Rate Limit Compliance (`rate_limit_compliance`)
- Sends burst traffic to test rate limiting
- Measures server-side rate limit enforcement
- Tests client-side rate limit respect
- **Key Metrics**: Rate limit hits, throttling behavior, compliance

### Resource Indicator (`resource_indicator`)
- Tests token binding to specific protected resources
- Validates resource-specific token scoping
- Tests cross-resource request failures
- **Key Metrics**: Binding violations, resource isolation, token scope

## Metrics and Output

Each test provides detailed metrics:
- **Request latencies**: p50, p95, p99 percentiles
- **Error categorization**: By type and frequency
- **Recovery times**: From various error conditions
- **Success rates**: For different operations
- **OAuth-specific metrics**: Token refreshes, nonce rotations, account switches

## Setting Up for Testing

1. **Initial OAuth setup**:
   ```bash
   PetrelLoad --namespace com.example.app --endpoint app.bsky.actor.getProfile --oauth-start
   # Follow the OAuth flow, then:
   PetrelLoad --namespace com.example.app --endpoint app.bsky.actor.getProfile --oauth-complete "http://localhost/callback?code=..."
   ```

2. **Multiple accounts** (for account switching tests):
   - Repeat the OAuth setup with different `--identifier` values
   - Store multiple accounts in the same namespace

3. **Test environment**:
   - Use a test/staging PDS when possible
   - Monitor server-side logs for compliance
   - Ensure network stability for consistent results

## Interpreting Results

### Good Signs
- High recovery success rates (>95%)
- Fast recovery times (<1s)
- Proper error categorization
- Consistent latency distributions
- No authentication race conditions

### Warning Signs
- Low recovery rates
- Long recovery times
- Uncategorized errors
- High authentication failure rates
- Memory leaks during long tests

### Critical Issues
- Authentication bypass
- Token leakage between accounts
- Persistent nonce failures
- Unhandled race conditions
- PKCE challenge reuse

## Comparison with Node.js Reference

Use alongside a Node.js ATProto client for validation:
1. Run identical test scenarios
2. Compare DPoP proof structures
3. Verify error handling patterns
4. Cross-validate compliance behavior

## Advanced Usage

### Custom Test Scenarios
The `OAuthStressTest` class can be extended with custom scenarios for specific edge cases in your implementation.

### Integration with CI/CD
Tests can be automated for regression detection:
```bash
# Quick smoke test
PetrelLoad --namespace ci.test --endpoint app.bsky.actor.getProfile --dpop-test compliance

# Full stress test (longer running)
PetrelLoad --namespace ci.test --endpoint app.bsky.actor.getProfile --oauth-stress --requests 1000 --concurrency 50
```

## Limitations

- Some DPoP edge cases require internal access to proof generation
- PKCE replay testing is limited without OAuth flow control
- Rate limit testing depends on server configuration
- Clock skew testing simulates rather than actually manipulating timestamps

These limitations are noted in the tool output when encountered.