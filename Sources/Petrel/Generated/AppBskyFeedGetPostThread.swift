import Foundation

// lexicon: 1, id: app.bsky.feed.getPostThread

public enum AppBskyFeedGetPostThread {
    public static let typeIdentifier = "app.bsky.feed.getPostThread"
    public struct Parameters: Parametrizable {
        public let uri: ATProtocolURI
        public let depth: Int?
        public let parentHeight: Int?

        public init(
            uri: ATProtocolURI,
            depth: Int? = nil,
            parentHeight: Int? = nil
        ) {
            self.uri = uri
            self.depth = depth
            self.parentHeight = parentHeight
        }
    }

    public struct Output: ATProtocolCodable {
        public let thread: OutputThreadUnion

        public let threadgate: AppBskyFeedDefs.ThreadgateView?

        // Standard public initializer
        public init(
            thread: OutputThreadUnion,

            threadgate: AppBskyFeedDefs.ThreadgateView? = nil

        ) {
            self.thread = thread

            self.threadgate = threadgate
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case notFound = "NotFound."
        public var description: String {
            return rawValue
        }
    }

    public indirect enum OutputThreadUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
        case appBskyFeedDefsThreadViewPost(AppBskyFeedDefs.ThreadViewPost)
        case appBskyFeedDefsNotFoundPost(AppBskyFeedDefs.NotFoundPost)
        case appBskyFeedDefsBlockedPost(AppBskyFeedDefs.BlockedPost)
        case unexpected(ATProtocolValueContainer)

        case pending(PendingDecodeData)

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            let depth = decoder.codingPath.count

            // Check if we're at a recursion depth that might cause stack overflow
            if depth > DecodingConfiguration.standard.threshold {
                if DecodingConfiguration.standard.debugMode {
                    print("🔄 Deferring deep decode for OutputThreadUnion at depth \(depth), type: \(typeValue)")
                }

                // Extract the raw JSON to decode asynchronously later
                let rawData = try JSONEncoder().encode(container.decode(JSONValue.self, forKey: .rawContent))
                self = .pending(PendingDecodeData(rawData: rawData, type: typeValue))
                return
            }

            switch typeValue {
            case "app.bsky.feed.defs#threadViewPost":
                let value = try AppBskyFeedDefs.ThreadViewPost(from: decoder)
                self = .appBskyFeedDefsThreadViewPost(value)
            case "app.bsky.feed.defs#notFoundPost":
                let value = try AppBskyFeedDefs.NotFoundPost(from: decoder)
                self = .appBskyFeedDefsNotFoundPost(value)
            case "app.bsky.feed.defs#blockedPost":
                let value = try AppBskyFeedDefs.BlockedPost(from: decoder)
                self = .appBskyFeedDefsBlockedPost(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .appBskyFeedDefsThreadViewPost(value):
                try container.encode("app.bsky.feed.defs#threadViewPost", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyFeedDefsNotFoundPost(value):
                try container.encode("app.bsky.feed.defs#notFoundPost", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyFeedDefsBlockedPost(value):
                try container.encode("app.bsky.feed.defs#blockedPost", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            case let .pending(pendingData):
                try container.encode(pendingData.type, forKey: .type)
                if let jsonObject = try? JSONSerialization.jsonObject(with: pendingData.rawData) {
                    try container.encode(JSONValue(jsonObject), forKey: .rawContent)
                } else {
                    throw EncodingError.invalidValue(
                        pendingData.rawData,
                        EncodingError.Context(
                            codingPath: encoder.codingPath,
                            debugDescription: "Could not encode pending data as JSON"
                        )
                    )
                }
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyFeedDefsThreadViewPost(value):
                hasher.combine("app.bsky.feed.defs#threadViewPost")
                hasher.combine(value)
            case let .appBskyFeedDefsNotFoundPost(value):
                hasher.combine("app.bsky.feed.defs#notFoundPost")
                hasher.combine(value)
            case let .appBskyFeedDefsBlockedPost(value):
                hasher.combine("app.bsky.feed.defs#blockedPost")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            case let .pending(pendingData):
                hasher.combine("pending")
                hasher.combine(pendingData.type)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
            case rawContent = "_rawContent"
        }

        public static func == (lhs: OutputThreadUnion, rhs: OutputThreadUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyFeedDefsThreadViewPost(lhsValue),
                .appBskyFeedDefsThreadViewPost(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyFeedDefsNotFoundPost(lhsValue),
                .appBskyFeedDefsNotFoundPost(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyFeedDefsBlockedPost(lhsValue),
                .appBskyFeedDefsBlockedPost(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            case let (.pending(lhsData), .pending(rhsData)):
                return lhsData.type == rhsData.type
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard other is OutputThreadUnion else { return false }
            return self == (other as! OutputThreadUnion)
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case .pending:
                return true
            case let .appBskyFeedDefsThreadViewPost(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyFeedDefsNotFoundPost(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyFeedDefsBlockedPost(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case let .pending(pendingData):
                do {
                    switch pendingData.type {
                    case "app.bsky.feed.defs#threadViewPost":
                        let value = try await SafeDecoder.decode(
                            AppBskyFeedDefs.ThreadViewPost.self,
                            from: pendingData.rawData
                        )
                        self = .appBskyFeedDefsThreadViewPost(value)
                    case "app.bsky.feed.defs#notFoundPost":
                        let value = try await SafeDecoder.decode(
                            AppBskyFeedDefs.NotFoundPost.self,
                            from: pendingData.rawData
                        )
                        self = .appBskyFeedDefsNotFoundPost(value)
                    case "app.bsky.feed.defs#blockedPost":
                        let value = try await SafeDecoder.decode(
                            AppBskyFeedDefs.BlockedPost.self,
                            from: pendingData.rawData
                        )
                        self = .appBskyFeedDefsBlockedPost(value)
                    default:
                        let unknownValue = ATProtocolValueContainer.string("Unknown type: \(pendingData.type)")
                        self = .unexpected(unknownValue)
                    }
                } catch {
                    if DecodingConfiguration.standard.debugMode {
                        print("❌ Failed to decode pending data for OutputThreadUnion: \(error)")
                    }
                    self = .unexpected(ATProtocolValueContainer.string("Failed to decode: \(error)"))
                }
            case let .appBskyFeedDefsThreadViewPost(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(AppBskyFeedDefs.ThreadViewPost.self, from: jsonData)
                    {
                        self = .appBskyFeedDefsThreadViewPost(decodedValue)
                    }
                }
            case let .appBskyFeedDefsNotFoundPost(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(AppBskyFeedDefs.NotFoundPost.self, from: jsonData)
                    {
                        self = .appBskyFeedDefsNotFoundPost(decodedValue)
                    }
                }
            case let .appBskyFeedDefsBlockedPost(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(AppBskyFeedDefs.BlockedPost.self, from: jsonData)
                    {
                        self = .appBskyFeedDefsBlockedPost(decodedValue)
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }
}

public extension ATProtoClient.App.Bsky.Feed {
    /// Get posts in a thread. Does not require auth, but additional metadata and filtering will be applied for authed requests.
    func getPostThread(input: AppBskyFeedGetPostThread.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetPostThread.Output?) {
        let endpoint = "app.bsky.feed.getPostThread"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode

        // Content-Type validation
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Data decoding and validation

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyFeedGetPostThread.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
