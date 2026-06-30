import Foundation

// lexicon: 1, id: chat.bsky.convo.listConvoRequests

public enum ChatBskyConvoListConvoRequests {
    public static let typeIdentifier = "chat.bsky.convo.listConvoRequests"
    public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?

        public init(
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let requests: [OutputRequestsUnion]

        /// Standard public initializer
        public init(
            cursor: String? = nil,

            requests: [OutputRequestsUnion]

        ) {
            self.cursor = cursor

            self.requests = requests
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            do {
                cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'cursor' — degrading to nil: \(error)")
                cursor = nil
            }

            requests = try container.decode([OutputRequestsUnion].self, forKey: .requests)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(requests, forKey: .requests)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let requestsValue = try requests.toCBORValue()
            map = map.adding(key: "requests", value: requestsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case requests
        }
    }

    public enum OutputRequestsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case chatBskyConvoDefsConvoView(ChatBskyConvoDefs.ConvoView)
        case chatBskyGroupDefsJoinRequestConvoView(ChatBskyGroupDefs.JoinRequestConvoView)
        case unexpected(ATProtocolValueContainer)
        public init(_ value: ChatBskyConvoDefs.ConvoView) {
            self = .chatBskyConvoDefsConvoView(value)
        }

        public init(_ value: ChatBskyGroupDefs.JoinRequestConvoView) {
            self = .chatBskyGroupDefsJoinRequestConvoView(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "chat.bsky.convo.defs#convoView":
                let value = try ChatBskyConvoDefs.ConvoView(from: decoder)
                self = .chatBskyConvoDefsConvoView(value)
            case "chat.bsky.group.defs#joinRequestConvoView":
                let value = try ChatBskyGroupDefs.JoinRequestConvoView(from: decoder)
                self = .chatBskyGroupDefsJoinRequestConvoView(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .chatBskyConvoDefsConvoView(value):
                try container.encode("chat.bsky.convo.defs#convoView", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyGroupDefsJoinRequestConvoView(value):
                try container.encode("chat.bsky.group.defs#joinRequestConvoView", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .chatBskyConvoDefsConvoView(value):
                hasher.combine("chat.bsky.convo.defs#convoView")
                hasher.combine(value)
            case let .chatBskyGroupDefsJoinRequestConvoView(value):
                hasher.combine("chat.bsky.group.defs#joinRequestConvoView")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: OutputRequestsUnion, rhs: OutputRequestsUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .chatBskyConvoDefsConvoView(lhsValue),
                .chatBskyConvoDefsConvoView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyGroupDefsJoinRequestConvoView(lhsValue),
                .chatBskyGroupDefsJoinRequestConvoView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? OutputRequestsUnion else { return false }
            return self == other
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .chatBskyConvoDefsConvoView(value):
                map = map.adding(key: "$type", value: "chat.bsky.convo.defs#convoView")

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
            case let .chatBskyGroupDefsJoinRequestConvoView(value):
                map = map.adding(key: "$type", value: "chat.bsky.group.defs#joinRequestConvoView")

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

public extension ATProtoClient.Chat.Bsky.Convo {
    // MARK: - listConvoRequests

    /// Returns a page of incoming conversation requests for the user. Direct convo requests are returned as convoView; group join requests made by the user are returned as joinRequestConvoView.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func listConvoRequests(input: ChatBskyConvoListConvoRequests.Parameters) async throws -> (responseCode: Int, data: ChatBskyConvoListConvoRequests.Output?) {
        let endpoint = "chat.bsky.convo.listConvoRequests"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "chat.bsky.convo.listConvoRequests")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        // Only validate Content-Type and decode on success. Error responses
        // (4xx/5xx) may have missing or different Content-Type headers and
        // are handled via the status code / structured error parser below.
        if (200 ... 299).contains(responseCode) {
            guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
                throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
            }

            if !contentType.lowercased().contains("application/json") {
                throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
            }

            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(ChatBskyConvoListConvoRequests.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.convo.listConvoRequests: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
