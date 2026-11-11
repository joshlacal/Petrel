import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Petrel
import PetrelFirehose
import Testing

/// Live smoke tests against real servers. Disabled unless the environment names an endpoint;
/// no credentials are involved. A rejected connection or a frame that fails to decode fails
/// the test.
///
/// ```
/// FIREHOSE_SMOKE_URL=wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos \
/// LABELS_SMOKE_URL=https://mod.bsky.app \
/// swift test --filter FirehoseLiveSmokeTests
/// ```
@Suite("Live firehose smoke")
struct FirehoseLiveSmokeTests {
  static let firehoseURL = ProcessInfo.processInfo.environment["FIREHOSE_SMOKE_URL"].flatMap(URL.init(string:))
  static let labelsURL = ProcessInfo.processInfo.environment["LABELS_SMOKE_URL"].flatMap(URL.init(string:))
  static let wanted = 300

  /// Runs `body` with a 30 second limit; cancelling ends the stream, so `body` returns what it has.
  static func withTimeout<T: Sendable>(_ body: @escaping @Sendable () async throws -> T) async throws -> T {
    let work = Task { try await body() }
    let timeout = Task {
      try await Task.sleep(nanoseconds: 30_000_000_000)
      work.cancel()
    }
    defer { timeout.cancel() }
    return try await work.value
  }

  @Test("FirehoseSubscription decodes a live relay stream", .enabled(if: firehoseURL != nil))
  func relayThroughFirehoseSubscription() async throws {
    let url = try #require(Self.firehoseURL)
    let subscription = FirehoseSubscription(url: url)

    let summary = try await Self.withTimeout { () -> (kinds: [String: Int], problems: [String], lastSeq: Int64) in
      var kinds: [String: Int] = [:]
      var problems: [String] = []
      var lastSeq: Int64 = 0
      var total = 0
      for try await element in subscription.events() {
        total += 1
        switch element {
        case let .event(event):
          if let seq = event.sequence {
            if seq <= lastSeq { problems.append("sequence went from \(lastSeq) to \(seq)") }
            lastSeq = seq
          }
          switch event {
          case let .commit(commit):
            kinds["commit", default: 0] += 1
            // `blocks` is a CAR rooted at the commit.
            do {
              let reader = try CARReader(data: commit.blocks)
              if reader.roots != [commit.commitCID] { problems.append("CAR root mismatch at \(commit.seq)") }
            } catch {
              problems.append("CAR parse failed at \(commit.seq): \(error)")
            }
          case .identity: kinds["identity", default: 0] += 1
          case .account: kinds["account", default: 0] += 1
          case .sync: kinds["sync", default: 0] += 1
          case .info: kinds["info", default: 0] += 1
          case .error: problems.append("error event")
          }
        case .sequenceGap:
          kinds["gap", default: 0] += 1
        case let .ignoredFrame(frame):
          problems.append("ignored frame: \(frame)")
        }
        if total == Self.wanted { break }
      }
      return (kinds, problems, lastSeq)
    }

    #expect(summary.problems.isEmpty, "\(summary.problems.prefix(5))")
    #expect(summary.kinds["commit", default: 0] > 0)
    #expect(summary.lastSeq > 0)
  }

  @Test(
    "the generated subscribeRepos message union decodes a live relay stream",
    .enabled(if: firehoseURL != nil)
  )
  func relayThroughGeneratedMessages() async throws {
    let url = try #require(Self.firehoseURL)
    let subscription = EventStreamSubscription<ComAtprotoSyncSubscribeRepos.Message>(
      nsid: "com.atproto.sync.subscribeRepos",
      configuration: .init(url: url)
    )

    let summary = try await Self.withTimeout { () -> (commits: Int, problems: [String]) in
      var commits = 0
      var problems: [String] = []
      var total = 0
      for try await element in subscription.events() {
        total += 1
        switch element {
        case let .message(.commit(commit), sequence):
          commits += 1
          if Int64(commit.seq) != sequence { problems.append("sequence mismatch") }
          if commit.ops.contains(where: { $0.action != "delete" && $0.cid == nil }) {
            problems.append("create/update without a cid at \(commit.seq)")
          }
        case .message, .sequenceGap:
          break
        case let .ignoredFrame(frame):
          problems.append("ignored frame: \(frame)")
        }
        if total == Self.wanted { break }
      }
      return (commits, problems)
    }

    #expect(summary.problems.isEmpty, "\(summary.problems.prefix(5))")
    #expect(summary.commits > 0)
  }

  @Test("LabelSubscription replays a live labeler from cursor 0", .enabled(if: labelsURL != nil))
  func labelerFromCursorZero() async throws {
    let service = try #require(Self.labelsURL)
    let subscription = LabelSubscription.labels(
      service: service,
      cursorStorage: InMemoryFirehoseCursorStorage(initialCursor: 0)
    )

    let summary = try await Self.withTimeout { () -> (labels: Int, problems: [String]) in
      var labels = 0
      var problems: [String] = []
      var batches = 0
      for try await element in subscription.events() {
        switch element {
        case let .message(.labels(batch), _):
          batches += 1
          labels += batch.labels.count
        case .message(.info, _), .sequenceGap:
          break
        case let .ignoredFrame(frame):
          problems.append("ignored frame: \(frame)")
        }
        if batches == 50 { break }
      }
      return (labels, problems)
    }

    #expect(summary.problems.isEmpty, "\(summary.problems.prefix(5))")
    #expect(summary.labels > 0)
  }
}
