// Streams live AT Protocol events with Petrel's three event-stream consumers.
//
//   swift run FirehoseDemo firehose  [service-url]   relay / PDS firehose (com.atproto.sync.subscribeRepos)
//   swift run FirehoseDemo labels    [service-url]   labeler stream (com.atproto.label.subscribeLabels)
//   swift run FirehoseDemo jetstream [service-url]   Jetstream (JSON; base host for v2, …/subscribe for v1)
//
// Add `--count N` to stop after N events (default 25). No account or credentials are needed.

import Foundation
import Petrel
import PetrelFirehose
import PetrelJetstream

@main
enum FirehoseDemo {
    static func main() async {
        var arguments = Array(CommandLine.arguments.dropFirst())
        var limit = 25
        if let flag = arguments.firstIndex(of: "--count"), flag + 1 < arguments.count,
           let value = Int(arguments[flag + 1])
        {
            limit = value
            arguments.removeSubrange(flag ... flag + 1)
        }
        let mode = arguments.first ?? "firehose"
        let service = arguments.dropFirst().first.flatMap(URL.init(string:))

        do {
            switch mode {
            case "firehose":
                try await firehose(service ?? URL(string: "https://bsky.network")!, limit: limit)
            case "labels":
                try await labels(service ?? URL(string: "https://mod.bsky.app")!, limit: limit)
            case "jetstream":
                try await jetstream(service ?? URL(string: "https://jetstream2.us-east.bsky.network")!, limit: limit)
            default:
                print("usage: FirehoseDemo [firehose|labels|jetstream] [service-url] [--count N]")
                exit(64)
            }
        } catch let error as EventStreamError {
            // The server ended the stream with an error frame (FutureCursor, ConsumerTooSlow, …).
            print("stream error \(error.name): \(error.message ?? "")")
            exit(1)
        } catch {
            print("failed: \(error)")
            exit(1)
        }
    }

    /// The full-fidelity firehose: CBOR frames with commits, identity and account events.
    static func firehose(_ service: URL, limit: Int) async throws {
        // Keep the cursor wherever your application keeps state; this one lives in memory.
        let cursor = InMemoryFirehoseCursorStorage()
        let subscription = FirehoseSubscription(service: service, cursorStorage: cursor, autoAcknowledge: true)
        print("connecting to \(subscription.configuration.url)")

        var seen = 0
        for try await element in subscription.events() {
            switch element {
            case let .event(.commit(commit)):
                for operation in try commit.records() {
                    let summary = operation.record.map { "\($0)".prefix(80) } ?? ""
                    print("#commit \(commit.seq) \(operation.action.rawValue) \(operation.uri(repo: commit.repo)) \(summary)")
                }
            case let .event(.identity(identity)):
                print("#identity \(identity.seq) \(identity.did) handle=\(identity.handle ?? "-")")
            case let .event(.account(account)):
                print("#account \(account.seq) \(account.did) active=\(account.active) status=\(account.status ?? "-")")
            case let .event(.sync(sync)):
                print("#sync \(sync.seq) \(sync.did) rev=\(sync.rev)")
            case let .event(.info(info)):
                print("#info \(info.name) \(info.message ?? "")")
            case .event(.error):
                break // error frames end the stream by throwing EventStreamError
            case let .sequenceGap(expected, received):
                print("gap: expected \(expected), got \(received)")
            case let .ignoredFrame(frame):
                print("ignored frame type=\(frame.type ?? "-") seq=\(frame.sequence.map(String.init) ?? "-")")
            }
            seen += 1
            if seen >= limit { break }
        }
        print("stopped after \(seen) events; cursor \(await subscription.currentCursor().map(String.init) ?? "none")")
    }

    /// Labels from a labeler, replayed from the beginning (cursor 0).
    static func labels(_ service: URL, limit: Int) async throws {
        let subscription = LabelSubscription.labels(
            service: service,
            cursorStorage: InMemoryFirehoseCursorStorage(initialCursor: 0),
            autoAcknowledge: true
        )
        print("connecting to \(subscription.configuration.url)")

        var seen = 0
        for try await element in subscription.events() {
            guard case let .message(.labels(batch), _) = element else { continue }
            for label in batch.labels {
                print("label \(batch.seq) \(label.neg == true ? "-" : "+")\(label.val) \(label.uri)")
                seen += 1
            }
            if seen >= limit { break }
        }
    }

    /// Jetstream: the same repository events as simplified JSON, filtered server-side.
    static func jetstream(_ service: URL, limit: Int) async throws {
        let subscription = JetstreamSubscription(configuration: .init(
            url: service,
            filter: JetstreamFilter(kinds: [.commit], collections: ["app.bsky.feed.post"])
        ))
        print("connecting to \(service) (\(subscription.configuration.resolvedAPIVersion))")

        var seen = 0
        for try await element in subscription.events() {
            guard case let .event(.commit(commit)) = element else { continue }
            var text = ""
            if let json = commit.recordJSON,
               let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any]
            {
                text = (object["text"] as? String ?? "").replacingOccurrences(of: "\n", with: " ")
            }
            print("\(commit.seq) \(commit.operation.rawValue) at://\(commit.did)/\(commit.collection)/\(commit.rkey) \(text.prefix(80))")
            seen += 1
            if seen >= limit { break }
        }
    }
}
