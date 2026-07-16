import Foundation
import Petrel
@testable import PetrelLoad
import Testing

@Suite("PetrelLoad CLI")
struct PetrelLoadCLITests {
    @Test("Supported value and flag options are parsed")
    func supportedOptions() throws {
        let arguments = try PetrelLoadCLI.parseArgs([
            "PetrelLoad",
            "--namespace", "com.example.petrel",
            "--endpoint", "app.bsky.feed.getTimeline",
            "--requests", "12",
            "--unauth",
        ])

        #expect(arguments["namespace"] == "com.example.petrel")
        #expect(arguments["endpoint"] == "app.bsky.feed.getTimeline")
        #expect(arguments["requests"] == "12")
        #expect(arguments["unauth"] == "true")
    }

    @Test("Removed options are rejected instead of silently ignored")
    func removedOptionsAreRejected() {
        do {
            _ = try PetrelLoadCLI.parseArgs(["PetrelLoad", "--method", "POST"])
            Issue.record("Expected removed option to be rejected")
        } catch let error as PetrelLoadCLI.ArgumentError {
            #expect(error == .unknownOption("method"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Value options require a value")
    func missingOptionValue() {
        do {
            _ = try PetrelLoadCLI.parseArgs(["PetrelLoad", "--endpoint"])
            Issue.record("Expected missing option value to be rejected")
        } catch let error as PetrelLoadCLI.ArgumentError {
            #expect(error == .missingValue("endpoint"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Request and concurrency counts must be positive integers")
    func positiveIntegerOptions() {
        for (option, value) in [
            ("requests", "nope"),
            ("requests", "0"),
            ("requests", "-1"),
            ("concurrency", "nope"),
            ("concurrency", "0"),
            ("concurrency", "-1"),
        ] {
            do {
                _ = try PetrelLoadCLI.parseArgs([
                    "PetrelLoad", "--\(option)", value,
                ])
                Issue.record("Expected --\(option) \(value) to be rejected")
            } catch let error as PetrelLoadCLI.ArgumentError {
                #expect(error == .invalidValue(option: option, value: value))
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    @Test("Base URLs must be absolute HTTP or HTTPS URLs")
    func validBaseURL() {
        for value in [
            "not a URL",
            "relative/path",
            "ftp://example.com",
            "https:///missing-host",
        ] {
            do {
                _ = try PetrelLoadCLI.parseArgs([
                    "PetrelLoad", "--base-url", value,
                ])
                Issue.record("Expected --base-url \(value) to be rejected")
            } catch let error as PetrelLoadCLI.ArgumentError {
                #expect(error == .invalidValue(option: "base-url", value: value))
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }

        #expect(throws: Never.self) {
            _ = try PetrelLoadCLI.parseArgs([
                "PetrelLoad", "--base-url", "http://127.0.0.1:8080", "--unauth",
            ])
        }
        #expect(throws: Never.self) {
            _ = try PetrelLoadCLI.parseArgs([
                "PetrelLoad", "--base-url", "https://bsky.social", "--unauth",
            ])
        }
    }

    @Test("OAuth modes require an explicit client ID and redirect URI pair")
    func oauthConfigurationPairIsRequired() {
        let common = [
            "PetrelLoad",
            "--namespace", "com.example.petrel",
            "--endpoint", "app.bsky.actor.getProfile",
            "--oauth-start",
        ]

        for incomplete in [
            common,
            common + ["--client-id", "https://client.example/oauth-client-metadata.json"],
            common + ["--redirect-uri", "com.example.client:/callback"],
        ] {
            do {
                _ = try PetrelLoadCLI.parseArgs(incomplete)
                Issue.record("Expected incomplete OAuth configuration to be rejected")
            } catch {
                #expect(String(describing: error).contains("--client-id"))
                #expect(String(describing: error).contains("--redirect-uri"))
            }
        }

        #expect(throws: Never.self) {
            _ = try PetrelLoadCLI.parseArgs(common + [
                "--client-id", "https://client.example/oauth-client-metadata.json",
                "--redirect-uri", "com.example.client:/callback",
            ])
        }
    }

    @Test("OAuth client and redirect arguments must be valid absolute URLs")
    func oauthConfigurationURLsAreValidated() {
        let common = [
            "PetrelLoad",
            "--namespace", "com.example.petrel",
            "--endpoint", "app.bsky.actor.getProfile",
            "--oauth-start",
        ]

        for (option, value, companionOption, companionValue) in [
            ("client-id", "http://client.example/metadata.json", "redirect-uri", "com.example.client:/callback"),
            ("client-id", "https://client.example:8443/metadata.json", "redirect-uri", "com.example.client:/callback"),
            ("client-id", "relative/metadata.json", "redirect-uri", "com.example.client:/callback"),
            ("redirect-uri", "relative/callback", "client-id", "https://client.example/metadata.json"),
        ] {
            do {
                _ = try PetrelLoadCLI.parseArgs(common + [
                    "--\(option)", value,
                    "--\(companionOption)", companionValue,
                ])
                Issue.record("Expected --\(option) \(value) to be rejected")
            } catch let error as PetrelLoadCLI.ArgumentError {
                #expect(error == .invalidValue(option: option, value: value))
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    @Test("Supplied OAuth arguments produce the exact OAuth configuration")
    func exactOAuthConfiguration() throws {
        let arguments = try PetrelLoadCLI.parseArgs([
            "PetrelLoad",
            "--namespace", "com.example.petrel",
            "--endpoint", "app.bsky.actor.getProfile",
            "--client-id", "https://client.example/oauth-client-metadata.json",
            "--redirect-uri", "com.example.client:/callback",
        ])

        let parsedConfiguration = try PetrelLoadCLI.oauthConfiguration(from: arguments)
        let configuration = try #require(parsedConfiguration)
        #expect(configuration.clientId == "https://client.example/oauth-client-metadata.json")
        #expect(configuration.redirectUri == "com.example.client:/callback")
        #expect(configuration.scope == "atproto transition:generic")
    }

    @Test("OAuth metadata is fetched and verified before browser launch")
    func oauthMetadataPreflight() async throws {
        let configuration = OAuthConfig(
            clientId: "https://client.example/oauth-client-metadata.json",
            redirectUri: "com.example.client:/callback",
            scope: "atproto transition:generic"
        )
        let probe = MetadataFetchProbe()

        try await PetrelLoadCLI.validateOAuthMetadata(for: configuration) { url in
            await probe.record(url)
            return PetrelLoadCLI.OAuthMetadataResponse(
                finalURL: url,
                statusCode: 200,
                contentType: "application/json; charset=utf-8",
                data: Data(#"""
                {
                  "client_id":"https://client.example/oauth-client-metadata.json",
                  "redirect_uris":["com.example.client:/callback"],
                  "grant_types":["authorization_code","refresh_token"],
                  "scope":"atproto transition:generic",
                  "response_types":["code"],
                  "dpop_bound_access_tokens":true
                }
                """#.utf8)
            )
        }

        #expect(await probe.lastURL == URL(string: configuration.clientId))

        await #expect(throws: URLError.self) {
            try await PetrelLoadCLI.validateOAuthMetadata(for: configuration) { _ in
                throw URLError(.cannotConnectToHost)
            }
        }

        await #expect(throws: PetrelLoadCLI.OAuthMetadataError.self) {
            try await PetrelLoadCLI.validateOAuthMetadata(for: configuration) { url in
                PetrelLoadCLI.OAuthMetadataResponse(
                    finalURL: url,
                    statusCode: 200,
                    contentType: "application/json",
                    data: Data(#"""
                    {
                      "client_id":"https://client.example/oauth-client-metadata.json",
                      "redirect_uris":["com.example.other:/callback"],
                      "grant_types":["authorization_code","refresh_token"],
                      "scope":"atproto transition:generic",
                      "response_types":["code"],
                      "dpop_bound_access_tokens":true
                    }
                    """#.utf8)
                )
            }
        }
    }

    @Test("OAuth completion instructions preserve the configured callback identity")
    func configuredCallbackInstructions() {
        let configuration = OAuthConfig(
            clientId: "https://client.example/oauth-client-metadata.json",
            redirectUri: "com.example.client:/callback",
            scope: "atproto transition:generic"
        )
        let instructions = PetrelLoadCLI.oauthCompletionInstructions(
            configuration: configuration,
            namespace: "com.example.petrel",
            endpoint: "app.bsky.actor.getProfile"
        )

        #expect(instructions.contains("com.example.client:/callback"))
        #expect(instructions.contains("--client-id \"https://client.example/oauth-client-metadata.json\""))
        #expect(instructions.contains("--redirect-uri \"com.example.client:/callback\""))
        #expect(instructions.contains("application registered for that URI"))
        #expect(instructions.contains("PetrelLoad exits after printing these instructions"))
        #expect(!instructions.contains("browser's address bar"))
    }

    @Test("Scenario plans distinguish concurrent load from serial state checks")
    func truthfulScenarioPlans() {
        #expect(PetrelLoadCLI.scenarioPlan(
            option: "oauth-test",
            value: "authenticated-load",
            total: 12,
            concurrency: 3
        ) == .concurrentRequests(total: 12, concurrency: 3))
        #expect(PetrelLoadCLI.scenarioPlan(
            option: "oauth-test",
            value: "refresh-sequence",
            total: 12,
            concurrency: 3
        ) == .serialRefreshes(count: 5))
        #expect(PetrelLoadCLI.scenarioPlan(
            option: "oauth-test",
            value: "session-snapshot",
            total: 12,
            concurrency: 3
        ) == .sessionSnapshot)
        #expect(PetrelLoadCLI.scenarioPlan(
            option: "dpop-test",
            value: "session-check",
            total: 12,
            concurrency: 3
        ) == .sessionCheck)
        #expect(PetrelLoadCLI.scenarioPlan(
            option: "dpop-test",
            value: "authenticated-load",
            total: 12,
            concurrency: 3
        ) == .concurrentRequests(total: 50, concurrency: 5))
        #expect(PetrelLoadCLI.scenarioPlan(
            option: "dpop-test",
            value: "refresh-check",
            total: 12,
            concurrency: 3
        ) == .singleRefresh)
    }

    @Test("Worker distribution executes every requested operation exactly once")
    func exactRequestDistribution() {
        #expect(PetrelLoadCLI.requestDistribution(total: 5, concurrency: 2) == [3, 2])
        #expect(PetrelLoadCLI.requestDistribution(total: 2, concurrency: 5) == [1, 1])

        let distribution = PetrelLoadCLI.requestDistribution(total: 101, concurrency: 10)
        #expect(distribution.count == 10)
        #expect(distribution.reduce(0, +) == 101)
        #expect((distribution.max() ?? 0) - (distribution.min() ?? 0) <= 1)
    }

    @Test("Unimplemented stress scenarios are rejected")
    func unimplementedScenario() {
        do {
            _ = try PetrelLoadCLI.parseArgs([
                "PetrelLoad",
                "--oauth-test", "audience_mismatch",
            ])
            Issue.record("Expected unimplemented scenario to be rejected")
        } catch let error as PetrelLoadCLI.ArgumentError {
            #expect(error == .invalidValue(
                option: "oauth-test",
                value: "audience_mismatch"
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Unsupported endpoints are rejected instead of running a different request")
    func unsupportedEndpoint() {
        do {
            _ = try PetrelLoadCLI.parseArgs([
                "PetrelLoad",
                "--endpoint", "com.atproto.server.getSession",
            ])
            Issue.record("Expected unsupported endpoint to be rejected")
        } catch let error as PetrelLoadCLI.ArgumentError {
            #expect(error == .invalidValue(
                option: "endpoint",
                value: "com.atproto.server.getSession"
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Usage advertises only implemented load controls")
    func usageMatchesImplementation() {
        #expect(PetrelLoadCLI.usage.contains("--requests"))
        #expect(PetrelLoadCLI.usage.contains("--oauth-start"))
        #expect(PetrelLoadCLI.usage.contains("--client-id"))
        #expect(PetrelLoadCLI.usage.contains("--redirect-uri"))
        #expect(!PetrelLoadCLI.usage.contains("--method"))
        #expect(!PetrelLoadCLI.usage.contains("--target-rps"))
        #expect(!PetrelLoadCLI.usage.contains("--force-refresh-interval"))
        #expect(!PetrelLoadCLI.usage.contains("--incident-only"))
    }

    @Test("Typed authentication events append as JSONL")
    func typedAuthEventJSONL() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("petrel-load-events-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try Data("existing\n".utf8).write(to: fileURL)

        let writer = try AuthEventJSONLWriter(fileURL: fileURL)
        #expect(writer.appendOffset == 9)
        try await writer.write(.logoutNoAutoSwitch(did: "did:plc:test"))

        let lines = try String(contentsOf: fileURL, encoding: .utf8)
            .split(separator: "\n")
        #expect(lines.count == 2)
        let record = try #require(lines.last?.data(using: .utf8))
        let object = try #require(
            JSONSerialization.jsonObject(with: record) as? [String: Any]
        )
        #expect((object["event"] as? String)?.contains("logoutNoAutoSwitch") == true)
        #expect(object["ts"] is Int)
    }

    @Test("OAuth harness uses only implemented CLI contracts")
    func oauthHarnessContract() throws {
        let scriptURL = packageRoot
            .appendingPathComponent("test-oauth-compliance.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        for removed in [
            "--body",
            "--burst-delay",
            "--burst-size",
            "--force-refresh-interval",
            "--incident-only",
            "--method",
            "--multi-account",
            "--no-rate-limit",
            "--simulate-expiry",
            "--target-rps",
            "--timeout",
        ] {
            #expect(!script.contains(removed), "Harness still uses removed option \(removed)")
        }

        for unsupported in [
            "account_switch_storm",
            "audience_mismatch",
            "clock-skew",
            "nonce-exhaustion",
            "rate_limit_compliance",
            "replay-jti",
            "stale-nonce",
            "wrong-ath",
        ] {
            #expect(!script.contains(unsupported), "Harness still names unsupported scenario \(unsupported)")
        }

        for truthfulScenario in [
            "authenticated-load",
            "refresh-sequence",
            "session-snapshot",
            "session-check",
            "refresh-check",
        ] {
            #expect(script.contains(truthfulScenario))
        }
        for overclaim in [
            "dpop_nonce_thrash",
            "token_refresh_race",
            "dpop_validation",
            "compliance",
            "nonce-test",
            "refresh-test",
        ] {
            #expect(!script.contains(overclaim), "Harness still overclaims \(overclaim)")
        }
        #expect(script.contains("--client-id \"$CLIENT_ID\""))
        #expect(script.contains("--redirect-uri \"$REDIRECT_URI\""))
        #expect(script.contains("simulate-ambiguous-timeout"))
        #expect(script.contains("source \"$ROOT/Scripts/activate-release-toolchain.sh\""))
        #expect(script.contains("\"$RELEASE_SWIFT\" run"))
        #expect(!script.contains("swift run"), "Harness must not resolve ambient Swift")
        #expect(script.contains("failures=$((failures + 1))"))
        #expect(script.contains("if (( failures > 0 )); then"))
    }

    @Test("OAuth harness has valid Bash syntax")
    func oauthHarnessSyntax() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-n", packageRoot.appendingPathComponent("test-oauth-compliance.sh").path]
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }

    @Test("Failed stress requests make the command exit nonzero")
    func failedStressRequestIsProcessFailure() throws {
        let result = try runPetrelLoad([
            "--namespace", "com.example.petrel.truthfulness.\(UUID().uuidString)",
            "--endpoint", "app.bsky.actor.getProfile",
            "--unauth",
            "--base-url", "http://127.0.0.1:1",
            "--requests", "1",
            "--concurrency", "1",
        ])

        #expect(result.terminationReason == .exit)
        #expect(result.terminationStatus == 1)
        #expect(result.standardOutput.contains("Failures: 1"))
        #expect(result.standardError.contains("PetrelLoad failed:"))
        #expect(!result.standardError.contains("Fatal error"))
    }

    @Test("Missing or partial OAuth configuration exits with usage status")
    func missingOAuthConfigurationIsUsageFailure() throws {
        let common = [
            "--namespace", "com.example.petrel.truthfulness.\(UUID().uuidString)",
            "--endpoint", "app.bsky.actor.getProfile",
            "--oauth-start",
        ]
        for incomplete in [
            common,
            common + ["--client-id", "https://client.example/oauth-client-metadata.json"],
            common + ["--redirect-uri", "com.example.client:/callback"],
        ] {
            let result = try runPetrelLoad(incomplete)
            #expect(result.terminationReason == .exit)
            #expect(result.terminationStatus == 2)
            #expect(result.standardError.contains("--client-id"))
            #expect(result.standardError.contains("--redirect-uri"))
            #expect(!result.standardError.contains("Fatal error"))
        }
    }

    @Test("OAuth scenario errors are not erased or force-trapped")
    func oauthErrorsReachProcessBoundary() throws {
        let source = try String(
            contentsOf: packageRoot.appendingPathComponent("Sources/PetrelLoad/main.swift"),
            encoding: .utf8
        )

        #expect(source.contains("await PetrelAuthEvents.addObserverAndWait"))
        #expect(source.contains("await PetrelAuthEvents.drain()"))
        #expect(!source.contains("Waiting for you to complete the OAuth flow"))
        #expect(!source.contains("try! await ATProtoClient"))
        #expect(!source.contains("try? await client.refreshToken()"))
        #expect(!source.contains("print(\"✗ API call FAILED:"))
        #expect(!source.contains("print(\"✗ API call after ambiguous path failed:"))
        #expect(!source.contains("print(\"ERROR: API call failed with:"))
        #expect(!source.contains("print(\"(simulateAmbiguous is only available in DEBUG builds)\")"))
        #expect(!source.contains("87a6c075b410.ngrok-free.app"))
        for overclaim in [
            "dpop_nonce_thrash",
            "token_refresh_race",
            "dpop_validation",
            "Running OAuth compliance check",
        ] {
            #expect(!source.contains(overclaim), "PetrelLoad still overclaims \(overclaim)")
        }
        let metadataPreflight = try #require(source.range(of: "try await validateOAuthMetadata"))
        let browserLaunch = try #require(source.range(of: "try openProcess.run()"))
        #expect(metadataPreflight.lowerBound < browserLaunch.lowerBound)
    }

    private struct ProcessResult {
        let terminationReason: Process.TerminationReason
        let terminationStatus: Int32
        let standardOutput: String
        let standardError: String
    }

    private actor MetadataFetchProbe {
        private(set) var lastURL: URL?

        func record(_ url: URL) {
            lastURL = url
        }
    }

    private func runPetrelLoad(_ arguments: [String]) throws -> ProcessResult {
        #if DEBUG
            let configuration = "debug"
        #else
            let configuration = "release"
        #endif
        let executableURL = packageRoot
            .appendingPathComponent(".build/\(configuration)/PetrelLoad")
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let standardOutput = Pipe()
        let standardError = Pipe()
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError
        try process.run()
        process.waitUntilExit()

        return ProcessResult(
            terminationReason: process.terminationReason,
            terminationStatus: process.terminationStatus,
            standardOutput: String(
                decoding: standardOutput.fileHandleForReading.readDataToEndOfFile(),
                as: UTF8.self
            ),
            standardError: String(
                decoding: standardError.fileHandleForReading.readDataToEndOfFile(),
                as: UTF8.self
            )
        )
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
