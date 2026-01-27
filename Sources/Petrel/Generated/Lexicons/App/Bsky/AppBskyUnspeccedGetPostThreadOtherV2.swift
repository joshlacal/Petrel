import Foundation

// lexicon: 1, id: app.bsky.unspecced.getPostThreadOtherV2

public enum AppBskyUnspeccedGetPostThreadOtherV2 {
    public static let typeIdentifier = "app.bsky.unspecced.getPostThreadOtherV2"

    public struct ThreadItem: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.unspecced.getPostThreadOtherV2#threadItem"
        public let uri: ATProtocolURI
        public let depth: Int
        public let value: ThreadItemValueUnion

        public init(
            uri: ATProtocolURI, depth: Int, value: ThreadItemValueUnion
        ) {
            self.uri = uri
            self.depth = depth
            self.value = value
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                uri = try container.decode(ATProtocolURI.self, forKey: .uri)
            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")
                throw error
            }
            do {
                depth = try container.decode(Int.self, forKey: .depth)
            } catch {
                LogManager.logError("Decoding error for required property 'depth': \(error)")
                throw error
            }
            do {
                value = try container.decode(ThreadItemValueUnion.self, forKey: .value)
            } catch {
                LogManager.logError("Decoding error for required property 'value': \(error)")
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

        public init(
            anchor: ATProtocolURI
        ) {
            self.anchor = anchor
        }
    }

    public struct Output: ATProtocolCodable {
        public let thread: [ThreadItem]

        /// Standard public initializer
        public init(
            thread: [ThreadItem]

        ) {
            self.thread = thread
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            thread = try container.decode([ThreadItem].self, forKey: .thread)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(thread, forKey: .thread)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let threadValue = try thread.toCBORValue()
            map = map.adding(key: "thread", value: threadValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case thread
        }
    }

    public enum ThreadItemValueUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case appBskyUnspeccedDefsThreadItemPost(AppBskyUnspeccedDefs.ThreadItemPost)
        case unexpected(ATProtocolValueContainer)
        public init(_ value: AppBskyUnspeccedDefs.ThreadItemPost) {
            self = .appBskyUnspeccedDefsThreadItemPost(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "app.bsky.unspecced.defs#threadItemPost":
                let value = try AppBskyUnspeccedDefs.ThreadItemPost(from: decoder)
                self = .appBskyUnspeccedDefsThreadItemPost(value)
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
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyUnspeccedDefsThreadItemPost(value):
                hasher.combine("app.bsky.unspecced.defs#threadItemPost")
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

        /// DAGCBOR encoding with field ordering
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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }
}

public extension ATProtoClient.App.Bsky.Unspecced {
    // MARK: - getPostThreadOtherV2

    /// (NOTE: this endpoint is under development and WILL change without notice. Don't use it until it is moved out of `unspecced` or your application WILL break) Get additional posts under a thread e.g. replies hidden by threadgate. Based on an anchor post at any depth of the tree, returns top-level replies below that anchor. It does not include ancestors nor the anchor itself. This should be called after exhausting `app.bsky.unspecced.getPostThreadV2`. Does not require auth, but additional metadata and filtering will be applied for authed requests.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getPostThreadOtherV2(input: AppBskyUnspeccedGetPostThreadOtherV2.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetPostThreadOtherV2.Output?) {
        let endpoint = "app.bsky.unspecced.getPostThreadOtherV2"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.unspecced.getPostThreadOtherV2")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200 ... 299).contains(responseCode) {
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(AppBskyUnspeccedGetPostThreadOtherV2.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.unspecced.getPostThreadOtherV2: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
