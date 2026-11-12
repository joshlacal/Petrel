import Darwin
import Foundation
import Petrel
import PetrelStatusphere

@main
enum StatusphereCLI {
    static func main() async {
        // Teach Petrel's dynamic ATProtocolValueContainer decoder about xyz.statusphere.* $types:
        PetrelStatusphereLexicons.register()

        let args = Array(CommandLine.arguments.dropFirst())
        let subcommand = args.first ?? "--demo"

        do {
            switch subcommand {
            case "--demo", "demo":
                try await runOfflineDemo()
            case "list":
                try await runListCommand(Array(args.dropFirst()))
            case "post":
                try await runPostCommand(Array(args.dropFirst()))
            case "--help", "-h", "help":
                printUsage()
            default:
                fputs("Unknown subcommand '\(subcommand)'.\n\n", stderr)
                printUsage()
                Foundation.exit(64)
            }
        } catch {
            fputs("Error: \(error)\n", stderr)
            Foundation.exit(1)
        }
    }

    // MARK: - 1. Offline End-to-End Overlay Verification (--demo)

    private static func runOfflineDemo() async throws {
        print("=== PetrelStatusphere Custom Lexicon Overlay Demo ===\n")

        let tid = await TIDGenerator.shared.nextTID()
        let createdAt = ATProtocolDate(date: Date(timeIntervalSince1970: 1_762_944_000))
        let statusRecord = XyzStatusphereStatus(
            status: "🚀",
            mood: "xyz.statusphere.defs#shipping",
            note: "Shipping custom ATmosphere schemas with Petrel 2.0",
            createdAt: createdAt
        )

        // 1. Canonical JSON wire encoding (includes "$type": "xyz.statusphere.status")
        let wireJSON = try JSONCoders.encode(statusRecord)
        let wireString = String(decoding: wireJSON, as: UTF8.self)
        print("1. Generated Record ($type = \(XyzStatusphereStatus.typeIdentifier)):")
        print("   rkey (TID): \(tid)")
        print("   wire JSON:  \(wireString)\n")

        // 2. Deterministic DAG-CBOR + CIDv1 content addressing (PetrelCore)
        let cborBytes = try DAGCBOR.encodeValue(statusRecord.toCBORValue())
        let recordCID = CID.fromDAGCBOR(cborBytes)
        print("2. Content-Addressed Repository Block:")
        print("   DAG-CBOR size: \(cborBytes.count) bytes")
        print("   CIDv1 (SHA-256): \(recordCID.string)\n")

        // 3. Dynamic $type hydration through ATProtocolValueContainer
        // Because PetrelStatusphereLexicons.register() ran at startup, untyped repo/Jetstream
        // containers automatically decode "$type": "xyz.statusphere.status" into XyzStatusphereStatus.
        let untypedContainer = try JSONCoders.decode(ATProtocolValueContainer.self, from: wireJSON)
        guard let hydrated = untypedContainer.decoded(XyzStatusphereStatus.self),
              hydrated == statusRecord
        else {
            throw StatusphereCLIError.roundTripMismatch
        }
        print("3. Dynamic ATProtocolValueContainer Round-Trip:")
        print("   Decoded status: \(hydrated.status)")
        print("   Decoded mood:   \(hydrated.mood ?? "none")")
        print("   Decoded note:   \(hydrated.note ?? "none")")
        print("   Equality check: PASSED (hydrated == statusRecord)\n")

        // 4. Generated ATProtoClient XRPC namespace extension + AppView proxy configuration
        let queryParams = XyzStatusphereGetStatuses.Parameters(limit: 20)
        let proxyRef = try ATProtoServiceReference(
            did: "did:web:api.statusphere.example",
            serviceID: "statusphere_appview"
        )
        print("4. Generated XRPC Namespace Extension:")
        print("   Endpoint:       \(XyzStatusphereGetStatuses.typeIdentifier)")
        print("   Swift call:     client.xyz.statusphere.getStatuses(input: .init(limit: \(queryParams.limit ?? 20)))")
        print("   atproto-proxy:  \(proxyRef)")
        print("\nAll overlay checks succeeded.")
    }

    // MARK: - 2. Read Custom Records from Any Public PDS (list)

    private static func runListCommand(_ args: [String]) async throws {
        guard let actorString = flagValue("--actor", in: args) else {
            fputs("Missing required '--actor <handle-or-did>'.\n\n", stderr)
            printUsage()
            Foundation.exit(64)
        }
        let limit = flagValue("--limit", in: args).flatMap(Int.init) ?? 10

        print("Resolving identity for '\(actorString)'...")
        let resolver = IdentityResolver()
        let identity = try await resolver.resolveIdentity(actorString)
        let did = identity.did
        guard let pdsURL = identity.pdsEndpoint else {
            throw StatusphereCLIError.missingPDSEndpoint(did.description)
        }

        print("Resolved \(actorString) -> \(did) (PDS: \(pdsURL.absoluteString))")
        let publicPDSClient = await ATProtoClient(baseURL: pdsURL)
        let (code, output) = try await publicPDSClient.com.atproto.repo.listRecords(
            input: .init(
                repo: .did(did),
                collection: NSID(nsidString: XyzStatusphereStatus.typeIdentifier),
                limit: limit
            )
        )

        guard (200 ..< 300).contains(code), let records = output?.records else {
            print("PDS returned HTTP \(code) with no records.")
            return
        }

        if records.isEmpty {
            print("No '\(XyzStatusphereStatus.typeIdentifier)' records found in \(did)'s repository yet.")
            return
        }

        for entry in records {
            if let status = entry.value.decoded(XyzStatusphereStatus.self) {
                let noteSuffix = status.note.map { " — \($0)" } ?? ""
                print("• \(status.status) [\(status.createdAt.date)] \(entry.uri)\(noteSuffix)")
            } else {
                print("• \(entry.uri) (unrecognized payload shape)")
            }
        }
    }

    // MARK: - 3. Publish a Custom Record to Your PDS (post)

    private static func runPostCommand(_ args: [String]) async throws {
        guard let handle = flagValue("--handle", in: args) else {
            fputs("Missing required '--handle <handle>'.\n\n", stderr)
            printUsage()
            Foundation.exit(64)
        }
        let emoji = flagValue("--emoji", in: args) ?? "🚀"
        let mood = flagValue("--mood", in: args)
        let note = flagValue("--note", in: args)

        let appPassword = try promptHidden("App Password for \(handle): ")
        guard !appPassword.isEmpty else {
            throw StatusphereCLIError.emptyPassword
        }

        let client = try await ATProtoClient(
            oauthConfig: OAuthConfig.loopback(port: 8765),
            namespace: "xyz.statusphere.cli",
            authMode: .legacy
        )
        let session = try await client.loginWithPassword(identifier: handle, password: appPassword)
        let accountDID = try DID(didString: session.did)

        let record = XyzStatusphereStatus(
            status: emoji,
            mood: mood,
            note: note,
            createdAt: ATProtocolDate(date: Date())
        )
        let rkey = try RecordKey(keyString: await TIDGenerator.next())
        let (code, created) = try await client.com.atproto.repo.createRecord(
            input: .init(
                repo: .did(accountDID),
                collection: NSID(nsidString: XyzStatusphereStatus.typeIdentifier),
                rkey: rkey,
                record: .knownType(record)
            )
        )

        guard (200 ..< 300).contains(code), let created else {
            throw StatusphereCLIError.unexpectedHTTPStatus(code)
        }

        print("Published custom Statusphere record:")
        print("  URI: \(created.uri)")
        print("  CID: \(created.cid.string)")
    }

    /// Example helper illustrating the generated `client.xyz.statusphere.getStatuses(input:)` XRPC extension.
    static func fetchAppViewStatuses(
        using client: ATProtoClient,
        limit: Int = 25
    ) async throws -> [XyzStatusphereGetStatuses.StatusView] {
        let (_, output) = try await client.xyz.statusphere.getStatuses(
            input: .init(limit: limit)
        )
        return output?.statuses ?? []
    }

    // MARK: - CLI Utilities

    private static func flagValue(_ flag: String, in args: [String]) -> String? {
        guard let idx = args.firstIndex(of: flag), idx + 1 < args.count else {
            return nil
        }
        return args[idx + 1]
    }

    private static func promptHidden(_ prompt: String) throws -> String {
        fputs(prompt, stderr)
        fflush(stderr)

        var originalTerm = termios()
        let hasTTY = tcgetattr(STDIN_FILENO, &originalTerm) == 0
        if hasTTY {
            var hiddenTerm = originalTerm
            hiddenTerm.c_lflag &= ~tcflag_t(ECHO)
            _ = tcsetattr(STDIN_FILENO, TCSANOW, &hiddenTerm)
        }
        defer {
            if hasTTY {
                _ = tcsetattr(STDIN_FILENO, TCSANOW, &originalTerm)
                fputs("\n", stderr)
            }
        }

        guard let line = readLine(strippingNewline: true) else {
            return ""
        }
        return line.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func printUsage() {
        print("""
        Usage:
          swift run StatusphereCLI [--demo]
          swift run StatusphereCLI list --actor <handle-or-did> [--limit <N>]
          swift run StatusphereCLI post --handle <handle> [--emoji 🚀] [--mood <token>] [--note <text>]
        """)
    }
}

enum StatusphereCLIError: LocalizedError {
    case roundTripMismatch
    case missingPDSEndpoint(String)
    case emptyPassword
    case unexpectedHTTPStatus(Int)

    var errorDescription: String? {
        switch self {
        case .roundTripMismatch:
            return "Decoded XyzStatusphereStatus did not match the encoded record."
        case let .missingPDSEndpoint(did):
            return "DID document for \(did) does not advertise an #atproto_pds service endpoint."
        case .emptyPassword:
            return "No App Password was entered."
        case let .unexpectedHTTPStatus(code):
            return "Server returned unexpected HTTP status \(code)."
        }
    }
}
