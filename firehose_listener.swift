#!/usr/bin/env swift

import Foundation

// Add the Petrel package directory to the search path
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// MARK: - Main Firehose Listener

@main
struct FirehoseListener {
    static func main() async {
        print("🔥 Petrel Firehose Listener")
        print("===========================")
        print("Connecting to Bluesky firehose...")
        print("Press Ctrl+C to stop\n")

        do {
            try await runFirehose()
        } catch {
            print("❌ Fatal error: \(error)")
            exit(1)
        }
    }

    static func runFirehose() async throws {
        // Create WebSocket connection to the firehose
        guard let url = URL(string: "wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos") else {
            throw NSError(domain: "Invalid URL", code: -1)
        }

        let session = URLSession(configuration: .default)
        let webSocketTask = session.webSocketTask(with: url)
        webSocketTask.resume()

        print("✅ Connected to firehose!\n")

        var eventCount = 0
        var commitCount = 0
        var identityCount = 0
        var accountCount = 0
        var postCount = 0
        var likeCount = 0
        var followCount = 0
        var repostCount = 0
        var profileCount = 0

        let startTime = Date()

        // Listen for messages
        while true {
            do {
                let message = try await webSocketTask.receive()

                switch message {
                case .data(let data):
                    eventCount += 1

                    // Try to decode the message type from CBOR
                    if let messageInfo = try? decodeFirehoseMessage(data) {
                        switch messageInfo.type {
                        case "#commit":
                            commitCount += 1
                            if let ops = messageInfo.ops {
                                for (action, path) in ops {
                                    processOperation(
                                        action: action,
                                        path: path,
                                        postCount: &postCount,
                                        likeCount: &likeCount,
                                        followCount: &followCount,
                                        repostCount: &repostCount,
                                        profileCount: &profileCount,
                                        eventCount: eventCount
                                    )
                                }
                            }

                        case "#identity":
                            identityCount += 1
                            if identityCount % 10 == 0 || eventCount < 50 {
                                print("🆔 Identity update event")
                            }

                        case "#account":
                            accountCount += 1
                            if accountCount % 10 == 0 || eventCount < 50 {
                                print("👤 Account update event")
                            }

                        default:
                            if eventCount < 50 {
                                print("📦 Event: \(messageInfo.type)")
                            }
                        }
                    }

                    // Show periodic statistics
                    if eventCount % 100 == 0 {
                        showStatistics(
                            eventCount: eventCount,
                            commitCount: commitCount,
                            identityCount: identityCount,
                            accountCount: accountCount,
                            postCount: postCount,
                            likeCount: likeCount,
                            followCount: followCount,
                            repostCount: repostCount,
                            profileCount: profileCount,
                            startTime: startTime
                        )
                    }

                case .string(let text):
                    print("📨 Text message: \(text)")

                @unknown default:
                    break
                }

            } catch {
                print("\n⚠️  Connection error: \(error)")
                print("🔄 Attempting to reconnect in 5 seconds...")
                try? await Task.sleep(nanoseconds: 5_000_000_000)

                // Reconnect
                webSocketTask.cancel(with: .goingAway, reason: nil)
                return try await runFirehose()
            }
        }
    }

    static func processOperation(
        action: String,
        path: String,
        postCount: inout Int,
        likeCount: inout Int,
        followCount: inout Int,
        repostCount: inout Int,
        profileCount: inout Int,
        eventCount: Int
    ) {
        if path.contains("app.bsky.feed.post") {
            postCount += 1
            if postCount % 5 == 0 || eventCount < 100 {
                let rkey = path.components(separatedBy: "/").last ?? "unknown"
                print("📝 \(action.uppercased()) post (\(rkey)) | Total: \(postCount)")
            }
        } else if path.contains("app.bsky.feed.like") {
            likeCount += 1
            if likeCount % 10 == 0 {
                print("❤️  \(action.uppercased()) like | Total: \(likeCount)")
            }
        } else if path.contains("app.bsky.graph.follow") {
            followCount += 1
            if followCount % 5 == 0 {
                print("👥 \(action.uppercased()) follow | Total: \(followCount)")
            }
        } else if path.contains("app.bsky.feed.repost") {
            repostCount += 1
            if repostCount % 10 == 0 {
                print("🔄 \(action.uppercased()) repost | Total: \(repostCount)")
            }
        } else if path.contains("app.bsky.actor.profile") {
            profileCount += 1
            if profileCount % 20 == 0 {
                print("👤 \(action.uppercased()) profile | Total: \(profileCount)")
            }
        }
    }

    static func showStatistics(
        eventCount: Int,
        commitCount: Int,
        identityCount: Int,
        accountCount: Int,
        postCount: Int,
        likeCount: Int,
        followCount: Int,
        repostCount: Int,
        profileCount: Int,
        startTime: Date
    ) {
        let elapsed = Date().timeIntervalSince(startTime)
        let rate = Double(eventCount) / max(elapsed, 1.0)

        print("\n" + String(repeating: "=", count: 60))
        print("📊 STATISTICS after \(eventCount) events")
        print(String(repeating: "=", count: 60))
        print("⏱️  Rate: \(String(format: "%.1f", rate)) events/sec")
        print("📦 Events: Commits: \(commitCount) | Identity: \(identityCount) | Account: \(accountCount)")
        print("📝 Posts: \(postCount)")
        print("❤️  Likes: \(likeCount)")
        print("👥 Follows: \(followCount)")
        print("🔄 Reposts: \(repostCount)")
        print("👤 Profiles: \(profileCount)")
        print(String(repeating: "=", count: 60) + "\n")
    }

    // MARK: - CBOR Decoding Helpers

    struct MessageInfo {
        let type: String
        let ops: [(action: String, path: String)]?
    }

    static func decodeFirehoseMessage(_ data: Data) throws -> MessageInfo {
        // Parse message type from CBOR header
        let messageType = parseMessageType(from: data)

        // If it's a commit, also parse operations
        var ops: [(String, String)]? = nil
        if messageType == "#commit" {
            ops = parseRepoOps(from: data)
        }

        return MessageInfo(type: messageType, ops: ops)
    }

    static func parseMessageType(from data: Data) -> String {
        // Look for the "t" field in CBOR which contains the message type
        guard let typeRange = data.range(of: Data([0x74])) else {
            return "unknown"
        }

        let offset = typeRange.upperBound
        guard offset < data.count else { return "unknown" }

        let stringLength = Int(data[offset])
        let stringStart = offset + 1

        guard stringStart + stringLength <= data.count else { return "unknown" }

        let typeData = data[stringStart..<stringStart + stringLength]
        return String(data: typeData, encoding: .utf8) ?? "unknown"
    }

    static func parseRepoOps(from data: Data) -> [(action: String, path: String)] {
        var operations: [(String, String)] = []

        let actionMarker = Data("action".utf8)
        let pathMarker = Data("path".utf8)
        let createMarker = Data("create".utf8)
        let updateMarker = Data("update".utf8)
        let deleteMarker = Data("delete".utf8)

        var searchStart = 0

        while searchStart < data.count - 50 {
            guard let actionRange = data.range(of: actionMarker, in: searchStart..<data.count) else {
                break
            }

            // Determine action type
            var action = "unknown"
            let checkOffset = actionRange.upperBound + 1

            if checkOffset < data.count - 10 {
                let checkData = data[checkOffset..<min(checkOffset + 10, data.count)]
                if checkData.starts(with: createMarker) {
                    action = "create"
                } else if checkData.starts(with: updateMarker) {
                    action = "update"
                } else if checkData.starts(with: deleteMarker) {
                    action = "delete"
                }
            }

            // Find associated path
            let pathSearchEnd = min(actionRange.lowerBound + 300, data.count)
            if let pathRange = data.range(of: pathMarker, in: actionRange.lowerBound..<pathSearchEnd) {
                let pathStart = pathRange.upperBound + 1
                if pathStart < data.count,
                   let pathEnd = data[pathStart...].firstIndex(where: { $0 < 0x20 || $0 > 0x7E }) {
                    let pathData = data[pathStart..<pathEnd]
                    if let path = String(data: pathData, encoding: .utf8), !path.isEmpty {
                        operations.append((action, path))
                    }
                }
            }

            searchStart = actionRange.upperBound
        }

        return operations
    }
}
