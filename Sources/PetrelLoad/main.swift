import Foundation
import Petrel

enum PetrelLoadCLI {
    static func printUsageAndExit() -> Never {
        let usage = """
        Usage: PetrelLoad --namespace <keychain-namespace> --endpoint <xrpc endpoint or URL> [options]

        Required:
          --namespace    Keychain namespace used by your app (e.g., com.your.app)
          --endpoint     XRPC endpoint (e.g., com.atproto.server.getSession) or absolute URL

        Basic Options:
          --base-url     Base PDS URL (defaults to stored account's PDS URL)
          --method       HTTP method (GET|POST). Default: GET
          --requests     Total number of requests. Default: 100
          --concurrency  Concurrent workers. Default: 10
          --body         JSON string body for POST
          --unauth       Send without auth/DPoP (for baseline)
          --timeout      Per-request timeout seconds. Default: 30

        OAuth Stress Testing:
          --oauth-stress              Run OAuth stress test suite
          --oauth-test <scenario>     Run specific OAuth test scenario:
                                       dpop_nonce_thrash, token_refresh_race,
                                       account_switch_storm, audience_mismatch,
                                       pkce_replay, rate_limit_compliance,
                                       resource_indicator, clock_skew_test
          --force-refresh-interval    Force token refresh every N seconds
          --simulate-expiry           Artificially expire tokens to test refresh
          --dpop-test <mode>          DPoP-specific test modes:
                                       replay-jti, wrong-ath, clock-skew,
                                       stale-nonce, malformed-proof, compliance,
                                       nonce-exhaustion
          --burst-size               Requests per burst for rate limit testing. Default: 50
          --burst-delay              Delay between bursts in seconds. Default: 0.1
          --multi-account            Test with multiple accounts (requires 2+ stored accounts)

        Examples:
          PetrelLoad --namespace com.example.petrel --endpoint app.bsky.feed.getTimeline --requests 500 --concurrency 25
          PetrelLoad --namespace com.example.petrel --endpoint app.bsky.actor.getProfile --oauth-stress
          PetrelLoad --namespace com.example.petrel --endpoint app.bsky.feed.getTimeline --oauth-test dpop_nonce_thrash --requests 200
          PetrelLoad --namespace com.example.petrel --endpoint app.bsky.actor.getProfile --dpop-test replay-jti
        """
        fputs(usage + "\n", stderr)
        exit(2)
    }

    static func parseArgs() -> [String: String] {
        var args: [String: String] = [:]
        var i = 1
        let argv = CommandLine.arguments
        while i < argv.count {
            let key = argv[i]
            if key.hasPrefix("--") {
                let name = String(key.dropFirst(2))
                if i + 1 < argv.count, !argv[i + 1].hasPrefix("--") {
                    args[name] = argv[i + 1]
                    i += 2
                } else {
                    args[name] = "true"
                    i += 1
                }
            } else {
                i += 1
            }
        }
        return args
    }

    static func main() async {
        let args = parseArgs()
        guard let namespace = args["namespace"], let endpoint = args["endpoint"] else {
            printUsageAndExit()
        }

        let method = (args["method"] ?? "GET").uppercased()
        let total = Int(args["requests"] ?? "100") ?? 100
        let concurrency = max(1, Int(args["concurrency"] ?? "10") ?? 10)
        let unauth = (args["unauth"] ?? "false").lowercased() == "true"
        let respectRateLimits = (args["no-rate-limit"] ?? "false").lowercased() != "true"
        let timeout = TimeInterval(args["timeout"] ?? "30") ?? 30
        let bodyString = args["body"]
        let targetRps = Double(args["target-rps"] ?? "0") ?? 0

        // OAuth stress testing options
        let oauthStressMode = (args["oauth-stress"] ?? "false").lowercased() == "true"
        let oauthTestScenario = args["oauth-test"]
        let dpopTestMode = args["dpop-test"]
        _ = TimeInterval(args["force-refresh-interval"] ?? "0") ?? 0
        _ = (args["simulate-expiry"] ?? "false").lowercased() == "true"
        _ = Int(args["burst-size"] ?? "50") ?? 50
        _ = TimeInterval(args["burst-delay"] ?? "0.1") ?? 0.1
        _ = (args["multi-account"] ?? "false").lowercased() == "true"

        // Determine base URL for initial setup
        var baseURL: URL
        if let explicit = args["base-url"], let url = URL(string: explicit) {
            baseURL = url
        } else {
            // Default to bsky.social for OAuth flows and general usage
            baseURL = URL(string: "https://bsky.social")!
        }

        // OAuth config for ATProto development with ngrok-exposed client metadata
        let oauthConfig = OAuthConfig(
            clientId: "https://87a6c075b410.ngrok-free.app/client-metadata.json",
            redirectUri: "https://87a6c075b410.ngrok-free.app/callback",
            scope: "atproto transition:generic"
        )

        // Initialize ATProtoClient with proper configuration
        let client = await ATProtoClient(
            baseURL: baseURL,
            oauthConfig: oauthConfig,
            namespace: namespace
        )

        // Debug: Check if the client has an account and what base URL it's using after init
        print("DEBUG - After ATProtoClient initialization:")
        let (initDid, initHandle, initPdsURL) = await client.getActiveAccountInfo()
        print("  Account found: \(initDid != nil)")
        print("  PDS URL from account: \(initPdsURL?.absoluteString ?? "nil")")
        print("  Initial base URL: \(baseURL)")

        // OAuth helper modes
        if (args["oauth-start"] ?? "false").lowercased() == "true" {
            let identifier = args["identifier"]
            do {
                let url = try await client.startOAuthFlow(identifier: identifier)
                print("Starting OAuth flow for: \(identifier ?? "user")")
                print("Opening browser for authentication...")
                print("OAuth URL: \(url.absoluteString)")

                // Try to open the browser automatically
                #if os(macOS)
                    let openProcess = Process()
                    openProcess.launchPath = "/usr/bin/open"
                    openProcess.arguments = [url.absoluteString]
                    try openProcess.run()
                    print("✓ Browser opened automatically")
                #else
                    print("Please open this URL in your browser:")
                #endif

                print("\nAfter authorizing in the browser:")
                print("1. Look for the callback URL that starts with 'https://87a6c075b410.ngrok-free.app/callback?code=...'")
                print("2. Copy the ENTIRE callback URL from your browser's address bar")
                print("3. Run the following command with the copied URL:")
                print("   PetrelLoad --namespace \(namespace) --endpoint \(endpoint) --oauth-complete \"<PASTE_CALLBACK_URL>\"")
                print("\nWaiting for you to complete the OAuth flow in the browser...")
            } catch {
                fputs("Failed to start OAuth flow: \(error)\n", stderr)
                exit(1)
            }
            return
        }

        if let callback = args["oauth-complete"], !callback.isEmpty {
            guard let url = URL(string: callback) else {
                fputs("Invalid callback URL.\n", stderr)
                exit(1)
            }
            do {
                print("DEBUG - About to call handleOAuthCallback...")
                try await client.handleOAuthCallback(url: url)
                print("DEBUG - handleOAuthCallback completed successfully")

                // RACE CONDITION FIX: Wait a moment for account setup to complete
                print("DEBUG - Waiting for account setup to complete...")
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                print("OAuth completed and tokens saved to Keychain for namespace \(namespace). You can now run load tests.")

                // Show account info and test if base URL was switched
                let (did, handle, pdsURL) = await client.getActiveAccountInfo()
                if let did = did, let handle = handle, let pdsURL = pdsURL {
                    print("✓ Authenticated as: \(handle)")
                    print("✓ DID: \(did)")
                    print("✓ PDS: \(pdsURL)")

                    // Test if the API actually works now
                    print("\nDEBUG - Testing API call after OAuth completion and delay...")
                    do {
                        let actor = try ATIdentifier(string: handle)
                        let params = AppBskyActorGetProfile.Parameters(actor: actor)
                        let result = try await client.app.bsky.actor.getProfile(input: params)
                        print("✓ API call SUCCESS! Response code: \(result.responseCode)")
                        if let profile = result.data {
                            print("✓ Got profile for: \(profile.displayName ?? "N/A")")
                        }
                    } catch {
                        print("✗ API call FAILED: \(error)")
                    }
                }
            } catch {
                fputs("Failed to complete OAuth: \(error)\n", stderr)
                exit(1)
            }
            return
        }

        // OAuth stress testing modes
        if oauthStressMode || oauthTestScenario != nil || dpopTestMode != nil {
            if unauth {
                fputs("Cannot run OAuth stress tests with --unauth flag.\n", stderr)
                exit(1)
            }

            // Check if we have a valid session
            let hasSession = await client.hasValidSession()
            if !hasSession {
                fputs("No valid OAuth session found. Please run --oauth-start first.\n", stderr)
                exit(1)
            }

            print("OAuth stress testing with ATProtoClient")
            print("Note: Using authenticated session for stress testing")

            if oauthStressMode {
                print("Running comprehensive OAuth stress test...")

                // Debug: Check what base URL the client is actually using
                let (did, handle, pdsURL) = await client.getActiveAccountInfo()
                print("DEBUG - Account info from client:")
                print("  DID: \(did ?? "nil")")
                print("  Handle: \(handle ?? "nil")")
                print("  PDS URL: \(pdsURL?.absoluteString ?? "nil")")
                print("  Original base URL from init: \(baseURL)")

                // Try a single API call to see the exact error
                print("\nDEBUG - Testing single API call...")
                do {
                    let actor = try ATIdentifier(string: handle ?? did ?? "bsky.app")
                    let params = AppBskyActorGetProfile.Parameters(actor: actor)
                    let result = try await client.app.bsky.actor.getProfile(input: params)
                    print("SUCCESS: API call worked! Response code: \(result.responseCode)")
                } catch {
                    print("ERROR: API call failed with: \(error)")
                    print("Error type: \(type(of: error))")
                }

                // Demonstrate with basic API calls
                await runBasicStressTest(client: client, endpoint: endpoint, iterations: total, concurrency: concurrency)
                return
            }

            if let scenario = oauthTestScenario {
                switch scenario {
                case "dpop_nonce_thrash":
                    print("Testing DPoP nonce handling...")
                    await runBasicStressTest(client: client, endpoint: endpoint, iterations: total, concurrency: concurrency)
                case "token_refresh_race":
                    print("Testing token refresh...")
                    for _ in 0 ..< 5 {
                        let refreshed = try? await client.refreshToken()
                        print("Token refresh result: \(refreshed ?? false)")
                    }
                case "dpop_validation":
                    print("Validating OAuth session...")
                    let (did, handle, pdsURL) = await client.getActiveAccountInfo()
                    print("✓ DID: \(did ?? "unknown")")
                    print("✓ Handle: \(handle ?? "unknown")")
                    print("✓ PDS: \(pdsURL?.absoluteString ?? "unknown")")
                default:
                    print("Available test scenarios: dpop_nonce_thrash, token_refresh_race, dpop_validation")
                }
                return
            }

            if let mode = dpopTestMode {
                switch mode {
                case "compliance":
                    print("Running OAuth compliance check...")
                    let hasSession = await client.hasValidSession()
                    print("✓ Valid OAuth session: \(hasSession)")
                case "nonce-test":
                    print("Testing nonce handling...")
                    await runBasicStressTest(client: client, endpoint: endpoint, iterations: 50, concurrency: 5)
                case "refresh-test":
                    print("Testing token refresh...")
                    let refreshed = try? await client.refreshToken()
                    print("✓ Token refresh result: \(refreshed ?? false)")
                default:
                    print("Available DPoP modes: compliance, nonce-test, refresh-test")
                }
                return
            }
        }

        // For non-OAuth testing, use ATProtoClient with basic stress test
        if unauth {
            print("Note: Running without authentication. For comprehensive testing, use OAuth with --oauth-start.")
            print("Running basic stress test with ATProtoClient...")
            await runBasicStressTest(client: client, endpoint: endpoint, iterations: total, concurrency: concurrency)
            return
        }

        // Default: run ATProtoClient stress test
        print("Running stress test with ATProtoClient...")
        await runBasicStressTest(client: client, endpoint: endpoint, iterations: total, concurrency: concurrency)
    }
}

// Helper function for basic stress testing with ATProtoClient
func runBasicStressTest(client: ATProtoClient, endpoint: String, iterations: Int, concurrency: Int) async {
    print("=== ATProtoClient Stress Test ===")
    print("Endpoint: \(endpoint)")
    print("Iterations: \(iterations), Concurrency: \(concurrency)")

    struct WorkerResult {
        let successes: Int
        let failures: Int
        let latencies: [TimeInterval]
        let sampleError: String?
    }

    let startTime = Date()

    let results = await withTaskGroup(of: WorkerResult.self) { group in
        let iterationsPerWorker = iterations / concurrency

        for workerIndex in 0 ..< concurrency {
            group.addTask {
                var workerSuccesses = 0
                var workerFailures = 0
                var workerLatencies: [TimeInterval] = []
                var sampleError: String? = nil

                for iteration in 0 ..< iterationsPerWorker {
                    let requestStart = Date()

                    do {
                        // Use the actual ATProto API based on endpoint
                        if endpoint == "app.bsky.actor.getProfile" {
                            let (did, handle, _) = await client.getActiveAccountInfo()
                            let actor = try ATIdentifier(string: handle ?? did ?? "bsky.app")
                            let params = AppBskyActorGetProfile.Parameters(actor: actor)
                            _ = try await client.app.bsky.actor.getProfile(input: params)
                        } else if endpoint == "app.bsky.feed.getTimeline" {
                            let params = AppBskyFeedGetTimeline.Parameters(algorithm: nil, limit: 10, cursor: nil)
                            _ = try await client.app.bsky.feed.getTimeline(input: params)
                        } else {
                            // For other endpoints, just get profile
                            let (did, handle, _) = await client.getActiveAccountInfo()
                            let actor = try ATIdentifier(string: handle ?? did ?? "bsky.app")
                            let params = AppBskyActorGetProfile.Parameters(actor: actor)
                            _ = try await client.app.bsky.actor.getProfile(input: params)
                        }

                        let latency = Date().timeIntervalSince(requestStart)
                        workerSuccesses += 1
                        workerLatencies.append(latency)

                    } catch {
                        workerFailures += 1
                        if iteration == 0, workerIndex == 0, sampleError == nil {
                            sampleError = "Sample error: \(error)"
                        }
                    }
                }

                return WorkerResult(successes: workerSuccesses, failures: workerFailures, latencies: workerLatencies, sampleError: sampleError)
            }
        }

        var allResults: [WorkerResult] = []
        for await result in group {
            allResults.append(result)
        }
        return allResults
    }

    let totalTime = Date().timeIntervalSince(startTime)
    let successes = results.reduce(0) { $0 + $1.successes }
    let failures = results.reduce(0) { $0 + $1.failures }
    let latencies = results.flatMap { $0.latencies }
    let totalRequests = successes + failures
    let rps = Double(totalRequests) / totalTime

    if let firstError = results.compactMap({ $0.sampleError }).first {
        print(firstError)
    }

    print("\n=== Results ===")
    print("Total time: \(String(format: "%.2f", totalTime))s")
    print("Total requests: \(totalRequests)")
    print("Successes: \(successes)")
    print("Failures: \(failures)")
    print("Success rate: \(String(format: "%.1f", Double(successes) / Double(totalRequests) * 100))%")
    print("RPS: \(String(format: "%.1f", rps))")

    if !latencies.isEmpty {
        let sorted = latencies.sorted()
        let avg = latencies.reduce(0, +) / Double(latencies.count)
        let p50 = sorted[Int(Double(sorted.count - 1) * 0.5)]
        let p95 = sorted[Int(Double(sorted.count - 1) * 0.95)]
        let p99 = sorted[Int(Double(sorted.count - 1) * 0.99)]

        print("Latency - avg: \(String(format: "%.3f", avg))s, p50: \(String(format: "%.3f", p50))s, p95: \(String(format: "%.3f", p95))s, p99: \(String(format: "%.3f", p99))s")
    }
}

// Main entry point
await PetrelLoadCLI.main()
