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
                "PetrelLoad", "--base-url", "http://127.0.0.1:8080",
            ])
        }
        #expect(throws: Never.self) {
            _ = try PetrelLoadCLI.parseArgs([
                "PetrelLoad", "--base-url", "https://bsky.social",
            ])
        }
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

        #expect(script.contains("dpop_nonce_thrash"))
        #expect(script.contains("token_refresh_race"))
        #expect(script.contains("dpop_validation"))
        #expect(script.contains("nonce-test"))
        #expect(script.contains("refresh-test"))
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

    @Test("OAuth scenario errors are not erased or force-trapped")
    func oauthErrorsReachProcessBoundary() throws {
        let source = try String(
            contentsOf: packageRoot.appendingPathComponent("Sources/PetrelLoad/main.swift"),
            encoding: .utf8
        )

        #expect(!source.contains("try! await ATProtoClient"))
        #expect(!source.contains("try? await client.refreshToken()"))
        #expect(!source.contains("print(\"✗ API call FAILED:"))
        #expect(!source.contains("print(\"✗ API call after ambiguous path failed:"))
        #expect(!source.contains("print(\"ERROR: API call failed with:"))
        #expect(!source.contains("print(\"(simulateAmbiguous is only available in DEBUG builds)\")"))
    }

    private struct ProcessResult {
        let terminationReason: Process.TerminationReason
        let terminationStatus: Int32
        let standardOutput: String
        let standardError: String
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
