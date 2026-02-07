#!/usr/bin/env swift sh

/*
 swift-sh is needed to import the Petrel package
 Install: brew install swift-sh

 Or run with: swift FirehoseDemo.swift (without parsing, just shows bytes)
 */

import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Simplified CBOR decoder for firehose messages
enum CBORDecoder {
    static func decodeHeader(from data: Data) -> (op: Int, type: String?)? {
        // Very basic CBOR header parsing
        // Looking for the message type in the header

        if data.count < 10 { return nil }

        var offset = 0

        // Skip to find the "t" field which contains the message type
        if let typeRange = data.range(of: Data([0x74]), in: offset ..< min(offset + 100, data.count)) {
            offset = typeRange.upperBound

            // Read string length
            if offset < data.count {
                let stringLength = Int(data[offset])
                offset += 1

                if offset + stringLength <= data.count {
                    let typeData = data[offset ..< offset + stringLength]
                    if let typeString = String(data: typeData, encoding: .utf8) {
                        return (op: 1, type: typeString)
                    }
                }
            }
        }

        return (op: 1, type: nil)
    }

    static func findRepoOps(in data: Data) -> [(action: String, path: String)] {
        var ops: [(String, String)] = []

        // Look for "action" field markers
        let actionMarker = Data([0x66, 0x61, 0x63, 0x74, 0x69, 0x6F, 0x6E]) // "action"
        let pathMarker = Data([0x64, 0x70, 0x61, 0x74, 0x68]) // "path"
        let createMarker = Data([0x66, 0x63, 0x72, 0x65, 0x61, 0x74, 0x65]) // "create"
        let updateMarker = Data([0x66, 0x75, 0x70, 0x64, 0x61, 0x74, 0x65]) // "update"
        let deleteMarker = Data([0x66, 0x64, 0x65, 0x6C, 0x65, 0x74, 0x65]) // "delete"

        var offset = 0
        while offset < data.count - 20 {
            if let actionRange = data.range(of: actionMarker, in: offset ..< data.count) {
                var action = "unknown"
                let checkOffset = actionRange.upperBound + 1

                if checkOffset < data.count - 10 {
                    if data[checkOffset ..< min(checkOffset + 7, data.count)].starts(with: createMarker) {
                        action = "create"
                    } else if data[checkOffset ..< min(checkOffset + 7, data.count)].starts(with: updateMarker) {
                        action = "update"
                    } else if data[checkOffset ..< min(checkOffset + 7, data.count)].starts(with: deleteMarker) {
                        action = "delete"
                    }
                }

                // Try to find path near the action
                if let pathRange = data.range(of: pathMarker, in: actionRange.lowerBound ..< min(actionRange.lowerBound + 200, data.count)) {
                    let pathStart = pathRange.upperBound + 1
                    if pathStart < data.count {
                        // Try to extract path
                        if let pathEnd = data[pathStart...].firstIndex(where: { $0 < 0x20 || $0 > 0x7E }) {
                            let pathData = data[pathStart ..< pathEnd]
                            if let path = String(data: pathData, encoding: .utf8), !path.isEmpty {
                                ops.append((action, path))
                            }
                        }
                    }
                }

                offset = actionRange.upperBound
            } else {
                break
            }
        }

        return ops
    }
}

enum FirehoseDemo {
    static func main() async {
        print("🔥 Bluesky Firehose Monitor (Decoded)")
        print("======================================")
        print("Connecting to wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos")
        print("Press Ctrl+C to stop\n")

        do {
            try await subscribeToFirehose()
        } catch {
            print("❌ Error: \(error)")
            exit(1)
        }
    }

    static func subscribeToFirehose() async throws {
        guard let url = URL(string: "wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos") else {
            throw NSError(domain: "Invalid URL", code: -1)
        }

        let session = URLSession(configuration: .default)
        let webSocketTask = session.webSocketTask(with: url)

        webSocketTask.resume()
        print("✅ Connected to firehose!\n")

        var eventCount = 0
        var postCount = 0
        var likeCount = 0
        var followCount = 0
        var startTime = Date()

        while true {
            do {
                let message = try await webSocketTask.receive()

                switch message {
                case let .data(data):
                    eventCount += 1

                    // Try to decode the header
                    if let header = CBORDecoder.decodeHeader(from: data) {
                        let messageType = header.type ?? "unknown"

                        // Find operations in the message
                        let ops = CBORDecoder.findRepoOps(in: data)

                        // Count by type
                        for (action, path) in ops {
                            let emoji: String
                            let label: String

                            if path.contains("app.bsky.feed.post") {
                                postCount += 1
                                emoji = "📝"
                                label = "POST"
                                if postCount % 5 == 0 || eventCount < 200 {
                                    print("\(emoji) \(action.uppercased()) \(label.lowercased()) (\(path.components(separatedBy: "/").last ?? "")) | Total posts: \(postCount)")
                                }
                            } else if path.contains("app.bsky.feed.like") {
                                likeCount += 1
                                emoji = "❤️ "
                                label = "LIKE"
                                if likeCount % 10 == 0 {
                                    print("\(emoji) \(action.uppercased()) \(label.lowercased()) | Total likes: \(likeCount)")
                                }
                            } else if path.contains("app.bsky.graph.follow") {
                                followCount += 1
                                emoji = "👥"
                                label = "FOLLOW"
                                if followCount % 5 == 0 {
                                    print("\(emoji) \(action.uppercased()) \(label.lowercased()) | Total follows: \(followCount)")
                                }
                            } else if path.contains("app.bsky.feed.repost") {
                                if eventCount % 20 == 0 {
                                    print("🔄 \(action.uppercased()) repost")
                                }
                            } else if path.contains("app.bsky.actor.profile") {
                                if eventCount % 30 == 0 {
                                    print("👤 \(action.uppercased()) profile")
                                }
                            }
                        }
                    }

                    // Show stats every 100 events
                    if eventCount % 100 == 0 {
                        let elapsed = Date().timeIntervalSince(startTime)
                        let rate = Double(eventCount) / max(elapsed, 1.0)

                        print("\n📊 Stats after \(eventCount) events:")
                        print("   Rate: \(String(format: "%.1f", rate)) events/sec")
                        print("   Posts: \(postCount) | Likes: \(likeCount) | Follows: \(followCount)")
                        print("   --------------------------------------------------\n")
                    }

                case let .string(text):
                    print("📨 Text message: \(text)")

                @unknown default:
                    break
                }
            } catch {
                print("\n⚠️  Connection error: \(error)")
                print("🔄 Reconnecting in 5 seconds...")
                try? await Task.sleep(nanoseconds: 5_000_000_000)

                // Reconnect
                webSocketTask.cancel(with: .goingAway, reason: nil)
                return try await subscribeToFirehose()
            }
        }
    }
}

// Run the demo
await FirehoseDemo.main()
