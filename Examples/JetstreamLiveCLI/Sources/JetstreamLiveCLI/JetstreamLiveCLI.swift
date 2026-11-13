import Foundation
import Petrel
import PetrelFirehose
import PetrelJetstream

/// Durable file-backed `FirehoseCursorStorage` actor so the CLI resumes cleanly across restarts.
actor FileFirehoseCursorStorage: FirehoseCursorStorage {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func loadCursor() async throws -> Int64? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let text = try String(contentsOf: fileURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Int64(text)
    }

    func saveCursor(_ cursor: Int64) async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("\(cursor)\n".utf8).write(to: fileURL, options: .atomic)
    }
}

@main
enum JetstreamLiveCLI {
    static func main() async {
        do {
            let options = try CLIOptions.parse(Array(CommandLine.arguments.dropFirst()))
            if options.showHelp {
                CLIOptions.printUsage()
                return
            }
            try await runStream(options)
        } catch let error as JetstreamSubscriptionError {
            switch error {
            case let .cursorStorageFailure(operation, message):
                fputs("Cursor storage \(operation) failed: \(message)\n", stderr)
            case let .connectionRejected(status, code, message):
                fputs("Jetstream connection rejected (HTTP \(status) \(code ?? "")): \(message ?? "")\n", stderr)
            default:
                fputs("Jetstream subscription error: \(error)\n", stderr)
            }
            Foundation.exit(1)
        } catch let error as EventStreamError {
            fputs("Jetstream ended with error frame \(error.name): \(error.message ?? "")\n", stderr)
            Foundation.exit(1)
        } catch {
            fputs("Error: \(error)\n", stderr)
            Foundation.exit(1)
        }
    }

    private static func runStream(_ options: CLIOptions) async throws {
        let cursorStore: any FirehoseCursorStorage = if let cursorPath = options.cursorFile {
            FileFirehoseCursorStorage(fileURL: URL(fileURLWithPath: cursorPath))
        } else {
            InMemoryFirehoseCursorStorage()
        }

        if let saved = try await cursorStore.loadCursor() {
            print("Resuming from persisted cursor: \(saved)")
        }

        let filter = JetstreamFilter(
            kinds: options.includeIdentityAndAccount ? [.commit, .identity, .account] : [.commit],
            dids: options.dids,
            collections: options.collections
        )

        let config = JetstreamClientConfiguration(
            host: options.host,
            mode: .live(),
            filter: filter,
            compression: options.compress,
            cursorStorage: cursorStore
        )

        let collectionsLabel = options.collections.isEmpty ? "*" : options.collections.joined(separator: ", ")
        print("Connecting to \(options.host.absoluteString) [collections=\(collectionsLabel), zstd=\(options.compress)]...")

        let client = JetstreamClient(configuration: config)
        var matchedCount = 0

        streamLoop: for try await batch in client.events() {
            for event in batch.events {
                switch event {
                case let .commit(commit):
                    guard let summary = formatCommit(commit, keyword: options.keyword) else {
                        continue
                    }
                    print(summary)
                    matchedCount += 1
                    if options.limit > 0, matchedCount >= options.limit {
                        break streamLoop
                    }

                case let .identity(identity):
                    let handle = identity.identity?.handle?.description ?? "-"
                    print("[#identity seq=\(identity.seq)] \(identity.did) handle=\(handle)")
                    matchedCount += 1
                    if options.limit > 0, matchedCount >= options.limit {
                        break streamLoop
                    }

                case let .account(account):
                    let active = account.account?.active ?? true
                    print("[#account  seq=\(account.seq)] \(account.did) active=\(active)")
                    matchedCount += 1
                    if options.limit > 0, matchedCount >= options.limit {
                        break streamLoop
                    }

                case .sync, .info:
                    break
                }
            }
        }

        if let finalCursor = try await cursorStore.loadCursor() {
            print("Stopped after \(matchedCount) matching event(s). Last cursor: \(finalCursor)")
        } else {
            print("Stopped after \(matchedCount) matching event(s).")
        }
    }

    private static func formatCommit(_ commit: JetstreamCommitEvent, keyword: String?) -> String? {
        let uri = "at://\(commit.did)/\(commit.collection)/\(commit.rkey)"

        guard commit.operation != .delete else {
            guard keyword == nil else { return nil }
            return "[delete seq=\(commit.seq)] \(uri)"
        }

        // Strongly typed Bluesky post decoding when streaming app.bsky.feed.post:
        if commit.collection == AppBskyFeedPost.typeIdentifier,
           let post = commit.decodedRecord()?.decoded(AppBskyFeedPost.self)
        {
            if let keyword, !post.text.localizedCaseInsensitiveContains(keyword) {
                return nil
            }
            let singleLine = post.text
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return "[\(commit.operation.rawValue) seq=\(commit.seq)] \(uri)\n  \(singleLine)"
        }

        // Generic fallback for any custom ATmosphere collection (e.g. xyz.statusphere.status):
        let rawPreview: String
        if let data = commit.recordJSON {
            rawPreview = String(decoding: data, as: UTF8.self)
        } else {
            rawPreview = "{}"
        }
        if let keyword, !rawPreview.localizedCaseInsensitiveContains(keyword) {
            return nil
        }
        let compact = rawPreview.count > 160 ? String(rawPreview.prefix(160)) + "…" : rawPreview
        return "[\(commit.operation.rawValue) seq=\(commit.seq)] \(uri)\n  \(compact)"
    }
}

struct CLIOptions {
    var host = URL(string: "https://jetstream2.us-east.bsky.network")!
    var collections: [String] = ["app.bsky.feed.post"]
    var dids: [String] = []
    var keyword: String?
    var compress = false
    var includeIdentityAndAccount = false
    var cursorFile: String?
    var limit = 15
    var showHelp = false

    static func parse(_ args: [String]) throws -> CLIOptions {
        var opts = CLIOptions()
        var customCollections: [String] = []
        var allCollections = false

        var index = 0
        while index < args.count {
            let arg = args[index]
            switch arg {
            case "--help", "-h":
                opts.showHelp = true
            case "--host":
                index += 1
                guard index < args.count, let url = URL(string: args[index]) else {
                    throw CLIError.invalidArgument("--host requires a valid URL")
                }
                opts.host = url
            case "--collection", "-c":
                index += 1
                guard index < args.count else {
                    throw CLIError.invalidArgument("--collection requires an NSID or prefix.*")
                }
                customCollections.append(args[index])
            case "--all-collections":
                allCollections = true
            case "--did":
                index += 1
                guard index < args.count else {
                    throw CLIError.invalidArgument("--did requires a DID string")
                }
                opts.dids.append(args[index])
            case "--keyword", "-k":
                index += 1
                guard index < args.count else {
                    throw CLIError.invalidArgument("--keyword requires search text")
                }
                opts.keyword = args[index]
            case "--compress":
                opts.compress = true
            case "--include-identity":
                opts.includeIdentityAndAccount = true
            case "--cursor-file":
                index += 1
                guard index < args.count else {
                    throw CLIError.invalidArgument("--cursor-file requires a file path")
                }
                opts.cursorFile = args[index]
            case "--limit", "-n":
                index += 1
                guard index < args.count, let count = Int(args[index]), count >= 0 else {
                    throw CLIError.invalidArgument("--limit requires a non-negative integer (0 = unlimited)")
                }
                opts.limit = count
            default:
                throw CLIError.invalidArgument("Unrecognized option '\(arg)'")
            }
            index += 1
        }

        if allCollections {
            opts.collections = []
        } else if !customCollections.isEmpty {
            opts.collections = customCollections
        }
        return opts
    }

    static func printUsage() {
        print("""
        JetstreamLiveCLI — Stream and filter live ATmosphere events with PetrelJetstream

        Usage:
          swift run JetstreamLiveCLI [options]

        Options:
          --host <url>            Jetstream host (default: https://jetstream2.us-east.bsky.network)
          -c, --collection <nsid> Collection NSID or prefix.* filter (repeatable; default: app.bsky.feed.post)
          --all-collections       Stream every collection across the network
          --did <did>             Restrict events to specific repository DID(s) (repeatable)
          -k, --keyword <text>    Case-insensitive text filter on decoded records
          --compress              Enable dictionary-based zstd WebSocket compression
          --include-identity      Also print #identity and #account lifecycle events
          --cursor-file <path>    Persist and resume sequence cursor atomically on disk
          -n, --limit <N>         Stop after N matching events (default: 15, 0 = run forever)
          -h, --help              Show this help message
        """)
    }
}

enum CLIError: LocalizedError {
    case invalidArgument(String)

    var errorDescription: String? {
        switch self {
        case let .invalidArgument(reason):
            return reason
        }
    }
}
