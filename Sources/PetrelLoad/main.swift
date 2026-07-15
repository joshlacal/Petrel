import Foundation
import Petrel

actor AuthEventJSONLWriter {
    nonisolated let appendOffset: UInt64
    private let handle: FileHandle

    init(fileURL: URL) throws {
        let openedHandle = try FileHandle(forWritingTo: fileURL)
        handle = openedHandle
        appendOffset = try openedHandle.seekToEnd()
    }

    deinit {
        try? handle.close()
    }

    func write(_ event: AuthEvent) throws {
        let record: [String: Any] = [
            "event": String(describing: event),
            "ts": Int(Date().timeIntervalSince1970),
        ]
        var data = try JSONSerialization.data(withJSONObject: record)
        data.append(0x0A)
        try handle.write(contentsOf: data)
    }
}

enum PetrelLoadCLI {
    enum ArgumentError: Error, Equatable, CustomStringConvertible {
        case invalidValue(option: String, value: String)
        case missingValue(String)
        case unexpectedArgument(String)
        case unknownOption(String)

        var description: String {
            switch self {
            case let .invalidValue(option, value):
                "Unsupported value for --\(option): \(value)"
            case let .missingValue(option):
                "Missing value for --\(option)"
            case let .unexpectedArgument(argument):
                "Unexpected argument: \(argument)"
            case let .unknownOption(option):
                "Unknown option: --\(option)"
            }
        }
    }

    static let usage = """
    Usage: PetrelLoad --namespace <keychain-namespace> --endpoint <xrpc endpoint> [options]

    Required:
      --namespace    Keychain namespace used by your app (e.g., com.your.app)
      --endpoint     Supported XRPC endpoint used by the load scenario

    Basic Options:
      --base-url     Base PDS URL (defaults to stored account's PDS URL)
      --requests     Total number of requests. Default: 100
      --concurrency  Concurrent workers. Default: 10
      --unauth       Use the lightweight unauthenticated client
      --keep-running Continuously loop the test until terminated

    Logging:
      --log-file     Append typed authentication events as JSONL

    OAuth Helpers:
      --oauth-start              Start an OAuth flow
      --identifier <handle>      Optional handle for --oauth-start
      --oauth-complete <URL>     Complete OAuth with the callback URL

    OAuth Stress Testing:
      --oauth-stress                   Run the implemented OAuth stress sequence
      --oauth-test <scenario>          dpop_nonce_thrash, token_refresh_race,
                                       or dpop_validation
      --dpop-test <mode>               compliance, nonce-test, or refresh-test
      --simulate-ambiguous-timeout     Exercise ambiguous refresh timeout handling

    Examples:
      PetrelLoad --namespace com.example.petrel --endpoint app.bsky.feed.getTimeline --requests 500 --concurrency 25
      PetrelLoad --namespace com.example.petrel --endpoint app.bsky.actor.getProfile --oauth-start --identifier alice.bsky.social
      PetrelLoad --namespace com.example.petrel --endpoint app.bsky.feed.getTimeline --oauth-test dpop_nonce_thrash --requests 200
      PetrelLoad --namespace com.example.petrel --endpoint app.bsky.actor.getProfile --dpop-test compliance
    """

    private static let valueOptions: Set<String> = [
        "base-url",
        "concurrency",
        "dpop-test",
        "endpoint",
        "identifier",
        "log-file",
        "namespace",
        "oauth-complete",
        "oauth-test",
        "requests",
    ]

    private static let flagOptions: Set<String> = [
        "keep-running",
        "oauth-start",
        "oauth-stress",
        "simulate-ambiguous-timeout",
        "unauth",
    ]

    private static let supportedEndpoints: Set<String> = [
        "app.bsky.actor.getProfile",
        "app.bsky.feed.getTimeline",
    ]

    private static let oauthTestScenarios: Set<String> = [
        "dpop_nonce_thrash",
        "dpop_validation",
        "token_refresh_race",
    ]

    private static let dpopTestModes: Set<String> = [
        "compliance",
        "nonce-test",
        "refresh-test",
    ]

    static func printUsageAndExit() -> Never {
        fputs(usage + "\n", stderr)
        exit(2)
    }

    static func parseArgs(_ argv: [String] = CommandLine.arguments) throws -> [String: String] {
        var args: [String: String] = [:]
        var i = 1
        while i < argv.count {
            let key = argv[i]
            guard key.hasPrefix("--"), key.count > 2 else {
                throw ArgumentError.unexpectedArgument(key)
            }

            let name = String(key.dropFirst(2))
            if flagOptions.contains(name) {
                args[name] = "true"
                i += 1
            } else if valueOptions.contains(name) {
                guard i + 1 < argv.count, !argv[i + 1].hasPrefix("--") else {
                    throw ArgumentError.missingValue(name)
                }
                args[name] = argv[i + 1]
                i += 2
            } else {
                throw ArgumentError.unknownOption(name)
            }
        }
        try validateOptionValues(args)
        return args
    }

    private static func validateOptionValues(_ args: [String: String]) throws {
        for option in ["requests", "concurrency"] {
            if let rawValue = args[option] {
                guard let value = Int(rawValue), value > 0 else {
                    throw ArgumentError.invalidValue(option: option, value: rawValue)
                }
            }
        }
        if let endpoint = args["endpoint"], !supportedEndpoints.contains(endpoint) {
            throw ArgumentError.invalidValue(option: "endpoint", value: endpoint)
        }
        if let scenario = args["oauth-test"], !oauthTestScenarios.contains(scenario) {
            throw ArgumentError.invalidValue(option: "oauth-test", value: scenario)
        }
        if let mode = args["dpop-test"], !dpopTestModes.contains(mode) {
            throw ArgumentError.invalidValue(option: "dpop-test", value: mode)
        }
    }

    static func requestDistribution(total: Int, concurrency: Int) -> [Int] {
        precondition(total > 0)
        precondition(concurrency > 0)

        let workerCount = min(total, concurrency)
        let quotient = total / workerCount
        let remainder = total % workerCount
        return (0 ..< workerCount).map { workerIndex in
            quotient + (workerIndex < remainder ? 1 : 0)
        }
    }

    static func main() async {
        let args: [String: String]
        do {
            args = try parseArgs()
        } catch {
            fputs("Argument error: \(error)\n", stderr)
            printUsageAndExit()
        }

        guard let namespace = args["namespace"], let endpoint = args["endpoint"] else {
            printUsageAndExit()
        }

        guard let total = Int(args["requests"] ?? "100"),
              let concurrency = Int(args["concurrency"] ?? "10")
        else {
            preconditionFailure("Validated numeric options became invalid")
        }
        let unauth = (args["unauth"] ?? "false").lowercased() == "true"
        let keepRunning = (args["keep-running"] ?? "false").lowercased() == "true"
        let logFilePath = args["log-file"]

        // OAuth stress testing options
        let oauthStressMode = (args["oauth-stress"] ?? "false").lowercased() == "true"
        let oauthTestScenario = args["oauth-test"]
        let dpopTestMode = args["dpop-test"]
        let simulateAmbiguous = (args["simulate-ambiguous-timeout"] ?? "false").lowercased() == "true"

        // Determine base URL for initial setup
        var baseURL: URL = if let explicit = args["base-url"], let url = URL(string: explicit) {
            url
        } else {
            // Default to bsky.social for OAuth flows and general usage
            URL(string: "https://bsky.social")!
        }

        // OAuth config for ATProto development with ngrok-exposed client metadata
        let oauthConfig = OAuthConfig(
            clientId: "https://87a6c075b410.ngrok-free.app/client-metadata.json",
            redirectUri: "https://87a6c075b410.ngrok-free.app/callback",
            scope: "atproto transition:generic"
        )

        // Initialize the exact client mode requested by the caller.
        let client: ATProtoClient = if unauth {
            await ATProtoClient(baseURL: baseURL)
        } else {
            try! await ATProtoClient(
                baseURL: baseURL,
                oauthConfig: oauthConfig,
                namespace: namespace
            )
        }

        // Setup log forwarder if requested
        if let logFilePath, !logFilePath.isEmpty {
            let fileURL = URL(fileURLWithPath: logFilePath)
            do {
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    guard FileManager.default.createFile(atPath: fileURL.path, contents: nil) else {
                        throw CocoaError(.fileWriteUnknown)
                    }
                }

                let writer = try AuthEventJSONLWriter(fileURL: fileURL)
                PetrelAuthEvents.addObserver { event in
                    do {
                        try await writer.write(event)
                    } catch {
                        print("WARN: Failed to append auth event: \(error)")
                    }
                }
                print("✓ Logging typed auth events to \(fileURL.path) from byte \(writer.appendOffset)")
            } catch {
                fputs("WARN: Failed to open log file \(logFilePath): \(error)\n", stderr)
            }
        }

        // Debug: Check if the client has an account and what base URL it's using after init
        print("DEBUG - After ATProtoClient initialization:")
        let (initDid, initHandle, initPdsURL) = await client.getActiveAccountInfo()
        print("  Account found: \(initDid != nil)")
        print("  Handle: \(initHandle ?? "nil")")
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
                if let did, let handle, let pdsURL {
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
        if oauthStressMode || oauthTestScenario != nil || dpopTestMode != nil || simulateAmbiguous {
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

            if simulateAmbiguous {
                print("Simulating ambiguous refresh timeout…")
                #if DEBUG
                    await client.simulateAmbiguousRefreshTimeout(durationSeconds: 900)
                #else
                    print("(simulateAmbiguous is only available in DEBUG builds)")
                #endif
                print("Triggering refresh after simulated ambiguous timeout…")
                let refreshed = try? await client.refreshToken()
                print("Refresh returned: \(refreshed == true ? "refreshed" : "not refreshed (still valid)")")
                // Make a quick API call to verify token still works
                do {
                    let (did, handle, _) = await client.getActiveAccountInfo()
                    let actor = try ATIdentifier(string: handle ?? did ?? "bsky.app")
                    let params = AppBskyActorGetProfile.Parameters(actor: actor)
                    let result = try await client.app.bsky.actor.getProfile(input: params)
                    print("✓ API call after ambiguous path: \(result.responseCode)")
                } catch {
                    print("✗ API call after ambiguous path failed: \(error)")
                }
                return
            }

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
        if keepRunning {
            print("Running continuous stress test. Press Ctrl+C to stop.")
            while true {
                await runBasicStressTest(client: client, endpoint: endpoint, iterations: total, concurrency: concurrency)
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s pause between loops
            }
        } else {
            print("Running stress test with ATProtoClient...")
            await runBasicStressTest(client: client, endpoint: endpoint, iterations: total, concurrency: concurrency)
        }
    }
}

/// Helper function for basic stress testing with ATProtoClient
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
        let requestDistribution = PetrelLoadCLI.requestDistribution(
            total: iterations,
            concurrency: concurrency
        )

        for (workerIndex, workerIterations) in requestDistribution.enumerated() {
            group.addTask {
                var workerSuccesses = 0
                var workerFailures = 0
                var workerLatencies: [TimeInterval] = []
                var sampleError: String? = nil

                for iteration in 0 ..< workerIterations {
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
    let latencies = results.flatMap(\.latencies)
    let totalRequests = successes + failures
    let rps = Double(totalRequests) / totalTime

    if let firstError = results.compactMap(\.sampleError).first {
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
