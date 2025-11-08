//
//  FirehoseMonitor
//  A CLI tool to monitor the Bluesky firehose with full record decoding
//

import Foundation
import Petrel

@main
struct FirehoseMonitor {
    static func main() async {
        print("🔥 Bluesky Firehose Monitor")
        print("=" * 80)
        print("Connecting to wss://bsky.network...")
        print("Press Ctrl+C to stop\n")

        do {
            // Create an unauthenticated client for public firehose access
            let client = await ATProtoClient(
                baseURL: URL(string: "https://bsky.network")!,
                oauthConfig: nil,  // No auth needed for firehose
                namespace: "firehose-monitor"
            )

            // Subscribe to the firehose
            let stream = try await client.com.atproto.sync.subscribeRepos()

            print("✅ Connected to firehose!\n")

            var stats = Stats()
            let startTime = Date()

            // Process messages
            for try await message in stream {
                stats.totalMessages += 1

                switch message {
                case .commit(let commit):
                    stats.commits += 1
                    handleCommit(commit, stats: &stats)

                case .identity(let identity):
                    stats.identityUpdates += 1
                    if stats.identityUpdates % 10 == 0 || stats.totalMessages < 50 {
                        print("👤 Identity Update: \(identity.did.description)")
                        if let handle = identity.handle {
                            print("   Handle: \(handle.description)")
                        }
                        print("   Seq: \(identity.seq) | Time: \(identity.time.description)")
                        print()
                    }

                case .account(let account):
                    stats.accountUpdates += 1
                    print("🔔 Account Update: \(account.did.description)")
                    print("   Active: \(account.active) | Seq: \(account.seq)")
                    if let status = account.status {
                        print("   Status: \(status)")
                    }
                    print()

                case .sync(let sync):
                    stats.syncMessages += 1
                    if stats.syncMessages % 20 == 0 {
                        print("🔄 Sync: \(sync.did.description) | Seq: \(sync.seq)")
                        print()
                    }

                case .info(let info):
                    print("ℹ️  Info: \(info.name)")
                    if let message = info.message {
                        print("   Message: \(message)")
                    }
                    print()
                }

                // Print stats every 100 messages
                if stats.totalMessages % 100 == 0 {
                    printStats(stats, startTime: startTime)
                }
            }
        } catch {
            print("\n❌ Error: \(error)")
            exit(1)
        }
    }

    static func handleCommit(_ commit: ComAtprotoSyncSubscribeRepos.Commit, stats: inout Stats) {
        // Process each operation in the commit
        for op in commit.ops {
            let action = op.action
            let path = op.path

            // Categorize by record type
            if path.contains("app.bsky.feed.post") {
                stats.posts += 1
                if stats.posts % 5 == 0 || stats.totalMessages < 100 {
                    print("📝 POST \(action.uppercased())")
                    print("   Repo: \(commit.repo.description)")
                    print("   Path: \(path)")
                    print("   CID: \(op.cid.string)")
                    print("   Seq: \(commit.seq) | Rev: \(commit.rev.description)")
                    print()
                }
            } else if path.contains("app.bsky.feed.like") {
                stats.likes += 1
                if stats.likes % 10 == 0 {
                    print("❤️  LIKE \(action.uppercased())")
                    print("   Repo: \(commit.repo.description)")
                    print("   Seq: \(commit.seq)")
                    print()
                }
            } else if path.contains("app.bsky.graph.follow") {
                stats.follows += 1
                if stats.follows % 5 == 0 {
                    print("👥 FOLLOW \(action.uppercased())")
                    print("   Repo: \(commit.repo.description)")
                    print("   Seq: \(commit.seq)")
                    print()
                }
            } else if path.contains("app.bsky.feed.repost") {
                stats.reposts += 1
                if stats.reposts % 10 == 0 {
                    print("🔄 REPOST \(action.uppercased())")
                    print("   Repo: \(commit.repo.description)")
                    print()
                }
            } else if path.contains("app.bsky.actor.profile") {
                stats.profiles += 1
                if stats.profiles % 10 == 0 {
                    print("🎭 PROFILE \(action.uppercased())")
                    print("   Repo: \(commit.repo.description)")
                    print()
                }
            } else {
                stats.other += 1
            }
        }
    }

    static func printStats(_ stats: Stats, startTime: Date) {
        let elapsed = Date().timeIntervalSince(startTime)
        let rate = Double(stats.totalMessages) / max(elapsed, 1.0)

        print("\n" + "=" * 80)
        print("📊 Statistics after \(stats.totalMessages) messages")
        print("=" * 80)
        print(String(format: "Rate: %.1f events/sec | Elapsed: %.1fs", rate, elapsed))
        print("\nMessage Types:")
        print(String(format: "  • Commits: %d", stats.commits))
        print(String(format: "  • Identity Updates: %d", stats.identityUpdates))
        print(String(format: "  • Account Updates: %d", stats.accountUpdates))
        print(String(format: "  • Sync Messages: %d", stats.syncMessages))
        print("\nRecord Types:")
        print(String(format: "  • Posts: %d", stats.posts))
        print(String(format: "  • Likes: %d", stats.likes))
        print(String(format: "  • Follows: %d", stats.follows))
        print(String(format: "  • Reposts: %d", stats.reposts))
        print(String(format: "  • Profiles: %d", stats.profiles))
        print(String(format: "  • Other: %d", stats.other))
        print("=" * 80 + "\n")
    }
}

// Helper for string repetition
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

// Statistics tracking
struct Stats {
    var totalMessages = 0
    var commits = 0
    var identityUpdates = 0
    var accountUpdates = 0
    var syncMessages = 0

    var posts = 0
    var likes = 0
    var follows = 0
    var reposts = 0
    var profiles = 0
    var other = 0
}
