import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
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
        case oauthConfigurationRequired
        case unexpectedArgument(String)
        case unknownOption(String)

        var description: String {
            switch self {
            case let .invalidValue(option, value):
                "Unsupported value for --\(option): \(value)"
            case let .missingValue(option):
                "Missing value for --\(option)"
            case .oauthConfigurationRequired:
                "OAuth modes require both --client-id and --redirect-uri"
            case let .unexpectedArgument(argument):
                "Unexpected argument: \(argument)"
            case let .unknownOption(option):
                "Unknown option: --\(option)"
            }
        }
    }

    enum OAuthMetadataError: Error, Equatable, CustomStringConvertible {
        case clientIDMismatch(expected: String, actual: String)
        case invalidContentType(String?)
        case invalidDocument
        case invalidStatus(Int)
        case redirected(expected: URL, actual: URL?)
        case missingRequirement(String)
        case redirectURIMissing(String)

        var description: String {
            switch self {
            case let .clientIDMismatch(expected, actual):
                "OAuth metadata client_id mismatch: expected \(expected), got \(actual)"
            case let .invalidContentType(contentType):
                "OAuth metadata must use application/json, got \(contentType ?? "no Content-Type")"
            case .invalidDocument:
                "OAuth client metadata is not a valid metadata document"
            case let .invalidStatus(status):
                "OAuth metadata fetch returned HTTP \(status); expected 200"
            case let .redirected(expected, actual):
                "OAuth metadata fetch redirected from \(expected) to \(actual?.absoluteString ?? "an unknown URL")"
            case let .missingRequirement(requirement):
                "OAuth metadata is missing required value: \(requirement)"
            case let .redirectURIMissing(redirectURI):
                "OAuth metadata does not declare redirect URI \(redirectURI)"
            }
        }
    }

    struct OAuthMetadataResponse {
        let finalURL: URL
        let statusCode: Int
        let contentType: String?
        let data: Data
    }

    enum ScenarioPlan: Equatable {
        case concurrentRequests(total: Int, concurrency: Int)
        case serialRefreshes(count: Int)
        case sessionSnapshot
        case sessionCheck
        case singleRefresh
    }

    typealias OAuthMetadataFetcher = @Sendable (URL) async throws -> OAuthMetadataResponse

    private struct OAuthClientMetadata: Decodable {
        let clientID: String
        let redirectURIs: [String]
        let grantTypes: [String]
        let scope: String
        let responseTypes: [String]
        let dpopBoundAccessTokens: Bool

        private enum CodingKeys: String, CodingKey {
            case clientID = "client_id"
            case redirectURIs = "redirect_uris"
            case grantTypes = "grant_types"
            case scope
            case responseTypes = "response_types"
            case dpopBoundAccessTokens = "dpop_bound_access_tokens"
        }
    }

    enum ScenarioError: Error, Equatable, CustomStringConvertible {
        case commandFailure(String)
        case debugBuildRequired(String)
        case missingAuthenticatedAccount
        case requestFailures(Int)

        var description: String {
            switch self {
            case let .commandFailure(message):
                message
            case let .debugBuildRequired(scenario):
                "\(scenario) requires a debug build"
            case .missingAuthenticatedAccount:
                "OAuth completed without an active account"
            case let .requestFailures(count):
                "\(count) request(s) failed"
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
      --keep-running Continuously loop; signal termination may interrupt pending typed-event delivery

    Logging:
      --log-file     Append typed authentication events as JSONL; final drain runs on orderly return or error

    OAuth Helpers:
      --client-id <URL>          HTTPS URL of the published OAuth client metadata
      --redirect-uri <URL>       Callback URI declared by that metadata
      --oauth-start              Start an OAuth flow
      --identifier <handle>      Optional handle for --oauth-start
      --oauth-complete <URL>     Complete OAuth with the callback URL

    OAuth Stress Testing:
      --oauth-stress                   Run an authenticated load sequence
      --oauth-test <scenario>          authenticated-load, refresh-sequence,
                                       or session-snapshot
      --dpop-test <mode>               session-check, authenticated-load,
                                       or refresh-check
      --simulate-ambiguous-timeout     Exercise ambiguous refresh timeout handling

    Examples:
      PetrelLoad --namespace com.example.petrel --endpoint app.bsky.feed.getTimeline --unauth --requests 500 --concurrency 25
      PetrelLoad --namespace com.example.petrel --endpoint app.bsky.actor.getProfile --client-id https://client.example/oauth-client-metadata.json --redirect-uri com.example.client:/callback --oauth-start --identifier alice.bsky.social
      PetrelLoad --namespace com.example.petrel --endpoint app.bsky.feed.getTimeline --client-id https://client.example/oauth-client-metadata.json --redirect-uri com.example.client:/callback --oauth-test authenticated-load --requests 200
      PetrelLoad --namespace com.example.petrel --endpoint app.bsky.actor.getProfile --client-id https://client.example/oauth-client-metadata.json --redirect-uri com.example.client:/callback --dpop-test session-check
    """

    private static let valueOptions: Set<String> = [
        "base-url",
        "client-id",
        "concurrency",
        "dpop-test",
        "endpoint",
        "identifier",
        "log-file",
        "namespace",
        "oauth-complete",
        "oauth-test",
        "requests",
        "redirect-uri",
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
        "authenticated-load",
        "refresh-sequence",
        "session-snapshot",
    ]

    private static let dpopTestModes: Set<String> = [
        "authenticated-load",
        "refresh-check",
        "session-check",
    ]

    static func printUsageAndExit() -> Never {
        writeStandardError(usage + "\n")
        exit(2)
    }

    static func writeStandardError(_ message: String) {
        FileHandle.standardError.write(Data(message.utf8))
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
        if let baseURL = args["base-url"] {
            _ = try validatedBaseURL(baseURL)
        }
        let unauthenticated = args["unauth"] == "true"
        if !unauthenticated {
            guard args["client-id"] != nil, args["redirect-uri"] != nil else {
                throw ArgumentError.oauthConfigurationRequired
            }
        }
        if let clientID = args["client-id"] {
            _ = try validatedClientID(clientID)
        }
        if let redirectURI = args["redirect-uri"] {
            _ = try validatedRedirectURI(redirectURI)
        }
    }

    private static func validatedBaseURL(_ value: String) throws -> URL {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host,
              !host.isEmpty,
              let url = components.url
        else {
            throw ArgumentError.invalidValue(option: "base-url", value: value)
        }
        return url
    }

    private static func validatedClientID(_ value: String) throws -> URL {
        guard let components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              let host = components.host,
              !host.isEmpty,
              components.port == nil,
              components.user == nil,
              components.password == nil,
              components.fragment == nil,
              let url = components.url
        else {
            throw ArgumentError.invalidValue(option: "client-id", value: value)
        }
        return url
    }

    private static func validatedRedirectURI(_ value: String) throws -> URL {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme,
              !scheme.isEmpty,
              components.fragment == nil,
              let url = components.url
        else {
            throw ArgumentError.invalidValue(option: "redirect-uri", value: value)
        }

        let webScheme = scheme.lowercased() == "http" || scheme.lowercased() == "https"
        let hasWebHost = components.host?.isEmpty == false
        let hasCustomPath = !webScheme && components.host == nil && components.path.hasPrefix("/") && components.path.count > 1
        guard (webScheme && hasWebHost) || hasCustomPath else {
            throw ArgumentError.invalidValue(option: "redirect-uri", value: value)
        }
        return url
    }

    static func oauthConfiguration(from args: [String: String]) throws -> OAuthConfig? {
        guard args["unauth"] != "true" else {
            return nil
        }
        guard let clientID = args["client-id"], let redirectURI = args["redirect-uri"] else {
            throw ArgumentError.oauthConfigurationRequired
        }
        _ = try validatedClientID(clientID)
        _ = try validatedRedirectURI(redirectURI)
        return OAuthConfig(
            clientId: clientID,
            redirectUri: redirectURI,
            scope: "atproto transition:generic"
        )
    }

    static func validateOAuthMetadata(
        for configuration: OAuthConfig,
        fetch: OAuthMetadataFetcher
    ) async throws {
        let clientIDURL = try validatedClientID(configuration.clientId)
        let response = try await fetch(clientIDURL)
        guard response.finalURL == clientIDURL else {
            throw OAuthMetadataError.redirected(expected: clientIDURL, actual: response.finalURL)
        }
        guard response.statusCode == 200 else {
            throw OAuthMetadataError.invalidStatus(response.statusCode)
        }
        let mediaType = response.contentType?
            .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard mediaType == "application/json" else {
            throw OAuthMetadataError.invalidContentType(response.contentType)
        }
        guard let metadata = try? JSONDecoder().decode(OAuthClientMetadata.self, from: response.data) else {
            throw OAuthMetadataError.invalidDocument
        }
        guard metadata.clientID == configuration.clientId else {
            throw OAuthMetadataError.clientIDMismatch(
                expected: configuration.clientId,
                actual: metadata.clientID
            )
        }
        guard metadata.redirectURIs.contains(configuration.redirectUri) else {
            throw OAuthMetadataError.redirectURIMissing(configuration.redirectUri)
        }
        guard metadata.grantTypes.contains("authorization_code") else {
            throw OAuthMetadataError.missingRequirement("grant_types.authorization_code")
        }
        guard metadata.grantTypes.contains("refresh_token") else {
            throw OAuthMetadataError.missingRequirement("grant_types.refresh_token")
        }
        guard metadata.responseTypes.contains("code") else {
            throw OAuthMetadataError.missingRequirement("response_types.code")
        }
        guard metadata.dpopBoundAccessTokens else {
            throw OAuthMetadataError.missingRequirement("dpop_bound_access_tokens=true")
        }
        let declaredScopes = Set(metadata.scope.split(whereSeparator: { $0.isWhitespace }).map(String.init))
        let requestedScopes = Set(configuration.scope.split(whereSeparator: { $0.isWhitespace }).map(String.init))
        guard requestedScopes.isSubset(of: declaredScopes), declaredScopes.contains("atproto") else {
            throw OAuthMetadataError.missingRequirement("scope=\(configuration.scope)")
        }
    }

    private static func fetchOAuthMetadata(at url: URL) async throws -> OAuthMetadataResponse {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthMetadataError.invalidDocument
        }
        return OAuthMetadataResponse(
            finalURL: httpResponse.url ?? url,
            statusCode: httpResponse.statusCode,
            contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"),
            data: data
        )
    }

    static func oauthCompletionInstructions(
        configuration: OAuthConfig,
        namespace: String,
        endpoint: String
    ) -> String {
        """
        After authorizing in the browser:
        1. The authorization server redirects to '\(configuration.redirectUri)'.
        2. The application registered for that URI must capture the ENTIRE callback URL, including its query string.
        3. Run the following command with that captured URL:
           PetrelLoad --namespace \(namespace) --endpoint \(endpoint) --client-id "\(configuration.clientId)" --redirect-uri "\(configuration.redirectUri)" --oauth-complete "<PASTE_CALLBACK_URL>"

        PetrelLoad exits after printing these instructions; it does not receive the callback itself.
        """
    }

    static func scenarioPlan(
        option: String,
        value: String,
        total: Int,
        concurrency: Int
    ) -> ScenarioPlan? {
        switch (option, value) {
        case ("oauth-test", "authenticated-load"):
            .concurrentRequests(total: total, concurrency: concurrency)
        case ("oauth-test", "refresh-sequence"):
            .serialRefreshes(count: 5)
        case ("oauth-test", "session-snapshot"):
            .sessionSnapshot
        case ("dpop-test", "session-check"):
            .sessionCheck
        case ("dpop-test", "authenticated-load"):
            .concurrentRequests(total: 50, concurrency: 5)
        case ("dpop-test", "refresh-check"):
            .singleRefresh
        default:
            nil
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

    static func main(metadataFetcher: OAuthMetadataFetcher? = nil) async throws {
        let args: [String: String]
        do {
            args = try parseArgs()
        } catch {
            writeStandardError("Argument error: \(error)\n")
            printUsageAndExit()
        }

        guard let namespace = args["namespace"], let endpoint = args["endpoint"] else {
            printUsageAndExit()
        }

        guard let total = Int(args["requests"] ?? "100"),
              let concurrency = Int(args["concurrency"] ?? "10")
        else {
            writeStandardError("Validated numeric options became invalid.\n")
            printUsageAndExit()
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
        let baseURL: URL = if let explicit = args["base-url"] {
            try validatedBaseURL(explicit)
        } else {
            // Default to bsky.social for OAuth flows and general usage
            ATProtoClient.defaultBaseURL
        }

        let oauthConfig = try oauthConfiguration(from: args)

        // Initialize the exact client mode requested by the caller.
        let client: ATProtoClient
        if unauth {
            client = await ATProtoClient(baseURL: baseURL)
        } else {
            guard let oauthConfig else {
                throw ArgumentError.oauthConfigurationRequired
            }
            client = try await ATProtoClient(
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
                await PetrelAuthEvents.addObserverAndWait { event in
                    do {
                        try await writer.write(event)
                    } catch {
                        print("WARN: Failed to append auth event: \(error)")
                    }
                }
                print("✓ Logging typed auth events to \(fileURL.path) from byte \(writer.appendOffset)")
            } catch {
                writeStandardError("WARN: Failed to open log file \(logFilePath): \(error)\n")
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
            guard let oauthConfig else {
                throw ArgumentError.oauthConfigurationRequired
            }
            let identifier = args["identifier"]
            do {
                let fetcher: OAuthMetadataFetcher = metadataFetcher ?? { url in
                    try await fetchOAuthMetadata(at: url)
                }
                try await validateOAuthMetadata(for: oauthConfig, fetch: fetcher)
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

                let completionInstructions = oauthCompletionInstructions(
                    configuration: oauthConfig,
                    namespace: namespace,
                    endpoint: endpoint
                )
                print("\n\(completionInstructions)")
            } catch {
                throw ScenarioError.commandFailure("Failed to start OAuth flow: \(error)")
            }
            return
        }

        if let callback = args["oauth-complete"], !callback.isEmpty {
            guard let url = URL(string: callback) else {
                throw ScenarioError.commandFailure("Invalid callback URL: \(callback)")
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
                guard let did, let handle, let pdsURL else {
                    throw ScenarioError.missingAuthenticatedAccount
                }
                print("✓ Authenticated as: \(handle)")
                print("✓ DID: \(did)")
                print("✓ PDS: \(pdsURL)")

                // Test if the API actually works now
                print("\nDEBUG - Testing API call after OAuth completion and delay...")
                let actor = try ATIdentifier(string: handle)
                let params = AppBskyActorGetProfile.Parameters(actor: actor)
                let result = try await client.app.bsky.actor.getProfile(input: params)
                print("✓ API call SUCCESS! Response code: \(result.responseCode)")
                if let profile = result.data {
                    print("✓ Got profile for: \(profile.displayName ?? "N/A")")
                }
            } catch {
                throw ScenarioError.commandFailure("OAuth completion or verification failed: \(error)")
            }
            return
        }

        // OAuth stress testing modes
        if oauthStressMode || oauthTestScenario != nil || dpopTestMode != nil || simulateAmbiguous {
            if unauth {
                throw ScenarioError.commandFailure("Cannot run OAuth stress tests with --unauth flag")
            }

            // Check if we have a valid session
            let hasSession = await client.hasValidSession()
            if !hasSession {
                throw ScenarioError.commandFailure("No valid OAuth session found. Please run --oauth-start first")
            }

            print("OAuth stress testing with ATProtoClient")
            print("Note: Using authenticated session for stress testing")

            if simulateAmbiguous {
                print("Simulating ambiguous refresh timeout…")
                #if DEBUG
                    await client.simulateAmbiguousRefreshTimeout(durationSeconds: 900)
                    print("Triggering refresh after simulated ambiguous timeout…")
                    let refreshed = try await client.refreshToken()
                    print("Refresh returned: \(refreshed == true ? "refreshed" : "not refreshed (still valid)")")
                    // Make a quick API call to verify token still works
                    let (did, handle, _) = await client.getActiveAccountInfo()
                    let actor = try ATIdentifier(string: handle ?? did ?? "bsky.app")
                    let params = AppBskyActorGetProfile.Parameters(actor: actor)
                    let result = try await client.app.bsky.actor.getProfile(input: params)
                    print("✓ API call after ambiguous path: \(result.responseCode)")
                    return
                #else
                    throw ScenarioError.debugBuildRequired("--simulate-ambiguous-timeout")
                #endif
            }

            if oauthStressMode {
                print("Running authenticated load sequence...")

                // Debug: Check what base URL the client is actually using
                let (did, handle, pdsURL) = await client.getActiveAccountInfo()
                print("DEBUG - Account info from client:")
                print("  DID: \(did ?? "nil")")
                print("  Handle: \(handle ?? "nil")")
                print("  PDS URL: \(pdsURL?.absoluteString ?? "nil")")
                print("  Original base URL from init: \(baseURL)")

                // Try a single API call to see the exact error
                print("\nDEBUG - Testing single API call...")
                let actor = try ATIdentifier(string: handle ?? did ?? "bsky.app")
                let params = AppBskyActorGetProfile.Parameters(actor: actor)
                let result = try await client.app.bsky.actor.getProfile(input: params)
                print("SUCCESS: API call worked! Response code: \(result.responseCode)")

                // Demonstrate with basic API calls
                try await runBasicStressTest(client: client, endpoint: endpoint, iterations: total, concurrency: concurrency)
                return
            }

            if let scenario = oauthTestScenario {
                guard let plan = scenarioPlan(
                    option: "oauth-test",
                    value: scenario,
                    total: total,
                    concurrency: concurrency
                ) else {
                    throw ArgumentError.invalidValue(option: "oauth-test", value: scenario)
                }
                switch plan {
                case let .concurrentRequests(iterations, workers):
                    print("Running authenticated request load...")
                    try await runBasicStressTest(
                        client: client,
                        endpoint: endpoint,
                        iterations: iterations,
                        concurrency: workers
                    )
                case let .serialRefreshes(count):
                    print("Running serial token refresh sequence...")
                    for _ in 0 ..< count {
                        let refreshed = try await client.refreshToken()
                        print("Token refresh result: \(refreshed)")
                    }
                case .sessionSnapshot:
                    print("Reading OAuth session snapshot...")
                    let (did, handle, pdsURL) = await client.getActiveAccountInfo()
                    print("✓ DID: \(did ?? "unknown")")
                    print("✓ Handle: \(handle ?? "unknown")")
                    print("✓ PDS: \(pdsURL?.absoluteString ?? "unknown")")
                case .sessionCheck, .singleRefresh:
                    throw ArgumentError.invalidValue(option: "oauth-test", value: scenario)
                }
                return
            }

            if let mode = dpopTestMode {
                guard let plan = scenarioPlan(
                    option: "dpop-test",
                    value: mode,
                    total: total,
                    concurrency: concurrency
                ) else {
                    throw ArgumentError.invalidValue(option: "dpop-test", value: mode)
                }
                switch plan {
                case .sessionCheck:
                    print("Checking for an OAuth session...")
                    let hasSession = await client.hasValidSession()
                    print("✓ Valid OAuth session: \(hasSession)")
                case let .concurrentRequests(iterations, workers):
                    print("Running authenticated request load...")
                    try await runBasicStressTest(
                        client: client,
                        endpoint: endpoint,
                        iterations: iterations,
                        concurrency: workers
                    )
                case .singleRefresh:
                    print("Checking token refresh...")
                    let refreshed = try await client.refreshToken()
                    print("✓ Token refresh result: \(refreshed)")
                case .serialRefreshes, .sessionSnapshot:
                    throw ArgumentError.invalidValue(option: "dpop-test", value: mode)
                }
                return
            }
        }

        // For non-OAuth testing, use ATProtoClient with basic stress test
        if unauth {
            print("Note: Running without authentication. For comprehensive testing, use OAuth with --oauth-start.")
            print("Running basic stress test with ATProtoClient...")
            try await runBasicStressTest(client: client, endpoint: endpoint, iterations: total, concurrency: concurrency)
            return
        }

        // Default: run ATProtoClient stress test
        if keepRunning {
            print(
                "Running continuous stress test. Press Ctrl+C to stop; " +
                    "signal termination may interrupt pending typed-event delivery."
            )
            while true {
                try await runBasicStressTest(client: client, endpoint: endpoint, iterations: total, concurrency: concurrency)
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s pause between loops
            }
        } else {
            print("Running stress test with ATProtoClient...")
            try await runBasicStressTest(client: client, endpoint: endpoint, iterations: total, concurrency: concurrency)
        }
    }
}

/// Helper function for basic stress testing with ATProtoClient
func runBasicStressTest(client: ATProtoClient, endpoint: String, iterations: Int, concurrency: Int) async throws {
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

    if failures > 0 {
        throw PetrelLoadCLI.ScenarioError.requestFailures(failures)
    }
}

/// Main entry point
var terminationStatus: Int32 = 0
do {
    try await PetrelLoadCLI.main()
} catch {
    PetrelLoadCLI.writeStandardError("PetrelLoad failed: \(error)\n")
    terminationStatus = 1
}

await PetrelAuthEvents.drain()
if terminationStatus != 0 {
    exit(terminationStatus)
}
