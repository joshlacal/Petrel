import Foundation

// lexicon: 1, id: app.bsky.unspecced.getPostThreadV2

public enum AppBskyUnspeccedGetPostThreadV2 {
    public static let typeIdentifier = "app.bsky.unspecced.getPostThreadV2"

    public struct ThreadItem: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.unspecced.getPostThreadV2#threadItem"
        public let uri: ATProtocolURI
        public let depth: Int
        public let value: ThreadItemValueUnion

        // Standard initializer
        public init(
            uri: ATProtocolURI, depth: Int, value: ThreadItemValueUnion
        ) {
            self.uri = uri
            self.depth = depth
            self.value = value
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                depth = try container.decode(Int.self, forKey: .depth)

            } catch {
                LogManager.logError("Decoding error for property 'depth': \(error)")
                throw error
            }
            do {
                value = try container.decode(ThreadItemValueUnion.self, forKey: .value)

            } catch {
                LogManager.logError("Decoding error for property 'value': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(uri, forKey: .uri)

            try container.encode(depth, forKey: .depth)

            try container.encode(value, forKey: .value)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(depth)
            hasher.combine(value)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if uri != other.uri {
                return false
            }

            if depth != other.depth {
                return false
            }

            if value != other.value {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)

            let depthValue = try depth.toCBORValue()
            map = map.adding(key: "depth", value: depthValue)

            let valueValue = try value.toCBORValue()
            map = map.adding(key: "value", value: valueValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case depth
            case value
        }
    }

    public struct Parameters: Parametrizable {
        public let anchor: ATProtocolURI
        public let above: Bool?
        public let below: Int?
        public let branchingFactor: Int?
        public let prioritizeFollowedUsers: Bool?
        public let sort: String?

        public init(
            anchor: ATProtocolURI,
            above: Bool? = nil,
            below: Int? = nil,
            branchingFactor: Int? = nil,
            prioritizeFollowedUsers: Bool? = nil,
            sort: String? = nil
        ) {
            self.anchor = anchor
            self.above = above
            self.below = below
            self.branchingFactor = branchingFactor
            self.prioritizeFollowedUsers = prioritizeFollowedUsers
            self.sort = sort
        }
    }

    public struct Output: ATProtocolCodable {
        public let thread: [ThreadItem]

        public let threadgate: AppBskyFeedDefs.ThreadgateView?

        public let hasHiddenReplies: Bool

        // Standard public initializer
        public init(
            thread: [ThreadItem],

            threadgate: AppBskyFeedDefs.ThreadgateView? = nil,

            hasHiddenReplies: Bool

        ) {
            self.thread = thread

            self.threadgate = threadgate

            self.hasHiddenReplies = hasHiddenReplies
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            thread = try container.decode([ThreadItem].self, forKey: .thread)

            threadgate = try container.decodeIfPresent(AppBskyFeedDefs.ThreadgateView.self, forKey: .threadgate)

            hasHiddenReplies = try container.decode(Bool.self, forKey: .hasHiddenReplies)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(thread, forKey: .thread)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(threadgate, forKey: .threadgate)

            try container.encode(hasHiddenReplies, forKey: .hasHiddenReplies)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let threadValue = try thread.toCBORValue()
            map = map.adding(key: "thread", value: threadValue)

            if let value = threadgate {
                // Encode optional property even if it's an empty array for CBOR
                let threadgateValue = try value.toCBORValue()
                map = map.adding(key: "threadgate", value: threadgateValue)
            }

            let hasHiddenRepliesValue = try hasHiddenReplies.toCBORValue()
            map = map.adding(key: "hasHiddenReplies", value: hasHiddenRepliesValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case thread
            case threadgate
            case hasHiddenReplies
        }
    }

    public enum ThreadItemValueUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case appBskyUnspeccedDefsThreadItemPost(AppBskyUnspeccedDefs.ThreadItemPost)
        case appBskyUnspeccedDefsThreadItemNoUnauthenticated(AppBskyUnspeccedDefs.ThreadItemNoUnauthenticated)
        case appBskyUnspeccedDefsThreadItemNotFound(AppBskyUnspeccedDefs.ThreadItemNotFound)
        case appBskyUnspeccedDefsThreadItemBlocked(AppBskyUnspeccedDefs.ThreadItemBlocked)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: AppBskyUnspeccedDefs.ThreadItemPost) {
            self = .appBskyUnspeccedDefsThreadItemPost(value)
        }

        public init(_ value: AppBskyUnspeccedDefs.ThreadItemNoUnauthenticated) {
            self = .appBskyUnspeccedDefsThreadItemNoUnauthenticated(value)
        }

        public init(_ value: AppBskyUnspeccedDefs.ThreadItemNotFound) {
            self = .appBskyUnspeccedDefsThreadItemNotFound(value)
        }

        public init(_ value: AppBskyUnspeccedDefs.ThreadItemBlocked) {
            self = .appBskyUnspeccedDefsThreadItemBlocked(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "app.bsky.unspecced.defs#threadItemPost":
                let value = try AppBskyUnspeccedDefs.ThreadItemPost(from: decoder)
                self = .appBskyUnspeccedDefsThreadItemPost(value)
            case "app.bsky.unspecced.defs#threadItemNoUnauthenticated":
                let value = try AppBskyUnspeccedDefs.ThreadItemNoUnauthenticated(from: decoder)
                self = .appBskyUnspeccedDefsThreadItemNoUnauthenticated(value)
            case "app.bsky.unspecced.defs#threadItemNotFound":
                let value = try AppBskyUnspeccedDefs.ThreadItemNotFound(from: decoder)
                self = .appBskyUnspeccedDefsThreadItemNotFound(value)
            case "app.bsky.unspecced.defs#threadItemBlocked":
                let value = try AppBskyUnspeccedDefs.ThreadItemBlocked(from: decoder)
                self = .appBskyUnspeccedDefsThreadItemBlocked(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .appBskyUnspeccedDefsThreadItemPost(value):
                try container.encode("app.bsky.unspecced.defs#threadItemPost", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyUnspeccedDefsThreadItemNoUnauthenticated(value):
                try container.encode("app.bsky.unspecced.defs#threadItemNoUnauthenticated", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyUnspeccedDefsThreadItemNotFound(value):
                try container.encode("app.bsky.unspecced.defs#threadItemNotFound", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyUnspeccedDefsThreadItemBlocked(value):
                try container.encode("app.bsky.unspecced.defs#threadItemBlocked", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyUnspeccedDefsThreadItemPost(value):
                hasher.combine("app.bsky.unspecced.defs#threadItemPost")
                hasher.combine(value)
            case let .appBskyUnspeccedDefsThreadItemNoUnauthenticated(value):
                hasher.combine("app.bsky.unspecced.defs#threadItemNoUnauthenticated")
                hasher.combine(value)
            case let .appBskyUnspeccedDefsThreadItemNotFound(value):
                hasher.combine("app.bsky.unspecced.defs#threadItemNotFound")
                hasher.combine(value)
            case let .appBskyUnspeccedDefsThreadItemBlocked(value):
                hasher.combine("app.bsky.unspecced.defs#threadItemBlocked")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: ThreadItemValueUnion, rhs: ThreadItemValueUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyUnspeccedDefsThreadItemPost(lhsValue),
                .appBskyUnspeccedDefsThreadItemPost(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyUnspeccedDefsThreadItemNoUnauthenticated(lhsValue),
                .appBskyUnspeccedDefsThreadItemNoUnauthenticated(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyUnspeccedDefsThreadItemNotFound(lhsValue),
                .appBskyUnspeccedDefsThreadItemNotFound(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyUnspeccedDefsThreadItemBlocked(lhsValue),
                .appBskyUnspeccedDefsThreadItemBlocked(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? ThreadItemValueUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .appBskyUnspeccedDefsThreadItemPost(value):
                map = map.adding(key: "$type", value: "app.bsky.unspecced.defs#threadItemPost")

                let valueDict = try value.toCBORValue()

                // If the value is already an OrderedCBORMap, merge its entries
                if let orderedMap = valueDict as? OrderedCBORMap {
                    for (key, value) in orderedMap.entries where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                } else if let dict = valueDict as? [String: Any] {
                    // Otherwise add each key-value pair from the dictionary
                    for (key, value) in dict where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                }
                return map
            case let .appBskyUnspeccedDefsThreadItemNoUnauthenticated(value):
                map = map.adding(key: "$type", value: "app.bsky.unspecced.defs#threadItemNoUnauthenticated")

                let valueDict = try value.toCBORValue()

                // If the value is already an OrderedCBORMap, merge its entries
                if let orderedMap = valueDict as? OrderedCBORMap {
                    for (key, value) in orderedMap.entries where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                } else if let dict = valueDict as? [String: Any] {
                    // Otherwise add each key-value pair from the dictionary
                    for (key, value) in dict where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                }
                return map
            case let .appBskyUnspeccedDefsThreadItemNotFound(value):
                map = map.adding(key: "$type", value: "app.bsky.unspecced.defs#threadItemNotFound")

                let valueDict = try value.toCBORValue()

                // If the value is already an OrderedCBORMap, merge its entries
                if let orderedMap = valueDict as? OrderedCBORMap {
                    for (key, value) in orderedMap.entries where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                } else if let dict = valueDict as? [String: Any] {
                    // Otherwise add each key-value pair from the dictionary
                    for (key, value) in dict where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                }
                return map
            case let .appBskyUnspeccedDefsThreadItemBlocked(value):
                map = map.adding(key: "$type", value: "app.bsky.unspecced.defs#threadItemBlocked")

                let valueDict = try value.toCBORValue()

                // If the value is already an OrderedCBORMap, merge its entries
                if let orderedMap = valueDict as? OrderedCBORMap {
                    for (key, value) in orderedMap.entries where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                } else if let dict = valueDict as? [String: Any] {
                    // Otherwise add each key-value pair from the dictionary
                    for (key, value) in dict where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                }
                return map
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .appBskyUnspeccedDefsThreadItemPost(value):
                return value.hasPendingData
            case let .appBskyUnspeccedDefsThreadItemNoUnauthenticated(value):
                return value.hasPendingData
            case let .appBskyUnspeccedDefsThreadItemNotFound(value):
                return value.hasPendingData
            case let .appBskyUnspeccedDefsThreadItemBlocked(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .appBskyUnspeccedDefsThreadItemPost(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyUnspeccedDefsThreadItemPost(value)
            case var .appBskyUnspeccedDefsThreadItemNoUnauthenticated(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyUnspeccedDefsThreadItemNoUnauthenticated(value)
            case var .appBskyUnspeccedDefsThreadItemNotFound(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyUnspeccedDefsThreadItemNotFound(value)
            case var .appBskyUnspeccedDefsThreadItemBlocked(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyUnspeccedDefsThreadItemBlocked(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }
}

public extension ATProtoClient.App.Bsky.Unspecced {
    // MARK: - getPostThreadV2

    /// (NOTE: this endpoint is under development and WILL change without notice. Don't use it until it is moved out of `unspecced` or your application WILL break) Get posts in a thread. It is based in an anchor post at any depth of the tree, and returns posts above it (recursively resolving the parent, without further branching to their replies) and below it (recursive replies, with branching to their replies). Does not require auth, but additional metadata and filtering will be applied for authed requests.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getPostThreadV2(input: AppBskyUnspeccedGetPostThreadV2.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetPostThreadV2.Output?) {
        let endpoint = "app.bsky.unspecced.getPostThreadV2"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)

        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyUnspeccedGetPostThreadV2.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
