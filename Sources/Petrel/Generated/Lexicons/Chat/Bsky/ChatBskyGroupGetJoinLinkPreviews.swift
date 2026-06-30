import Foundation

// lexicon: 1, id: chat.bsky.group.getJoinLinkPreviews

public enum ChatBskyGroupGetJoinLinkPreviews {
    public static let typeIdentifier = "chat.bsky.group.getJoinLinkPreviews"
    public struct Parameters: Parametrizable {
        public let codes: [String]

        public init(
            codes: [String]
        ) {
            self.codes = codes
        }
    }

    public struct Output: ATProtocolCodable {
        public let joinLinkPreviews: [OutputJoinLinkPreviewsUnion]

        /// Standard public initializer
        public init(
            joinLinkPreviews: [OutputJoinLinkPreviewsUnion]

        ) {
            self.joinLinkPreviews = joinLinkPreviews
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            joinLinkPreviews = try container.decode([OutputJoinLinkPreviewsUnion].self, forKey: .joinLinkPreviews)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(joinLinkPreviews, forKey: .joinLinkPreviews)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let joinLinkPreviewsValue = try joinLinkPreviews.toCBORValue()
            map = map.adding(key: "joinLinkPreviews", value: joinLinkPreviewsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case joinLinkPreviews
        }
    }

    public enum OutputJoinLinkPreviewsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case chatBskyGroupDefsJoinLinkPreviewView(ChatBskyGroupDefs.JoinLinkPreviewView)
        case chatBskyGroupDefsDisabledJoinLinkPreviewView(ChatBskyGroupDefs.DisabledJoinLinkPreviewView)
        case chatBskyGroupDefsInvalidJoinLinkPreviewView(ChatBskyGroupDefs.InvalidJoinLinkPreviewView)
        case unexpected(ATProtocolValueContainer)
        public init(_ value: ChatBskyGroupDefs.JoinLinkPreviewView) {
            self = .chatBskyGroupDefsJoinLinkPreviewView(value)
        }

        public init(_ value: ChatBskyGroupDefs.DisabledJoinLinkPreviewView) {
            self = .chatBskyGroupDefsDisabledJoinLinkPreviewView(value)
        }

        public init(_ value: ChatBskyGroupDefs.InvalidJoinLinkPreviewView) {
            self = .chatBskyGroupDefsInvalidJoinLinkPreviewView(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "chat.bsky.group.defs#joinLinkPreviewView":
                let value = try ChatBskyGroupDefs.JoinLinkPreviewView(from: decoder)
                self = .chatBskyGroupDefsJoinLinkPreviewView(value)
            case "chat.bsky.group.defs#disabledJoinLinkPreviewView":
                let value = try ChatBskyGroupDefs.DisabledJoinLinkPreviewView(from: decoder)
                self = .chatBskyGroupDefsDisabledJoinLinkPreviewView(value)
            case "chat.bsky.group.defs#invalidJoinLinkPreviewView":
                let value = try ChatBskyGroupDefs.InvalidJoinLinkPreviewView(from: decoder)
                self = .chatBskyGroupDefsInvalidJoinLinkPreviewView(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .chatBskyGroupDefsJoinLinkPreviewView(value):
                try container.encode("chat.bsky.group.defs#joinLinkPreviewView", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyGroupDefsDisabledJoinLinkPreviewView(value):
                try container.encode("chat.bsky.group.defs#disabledJoinLinkPreviewView", forKey: .type)
                try value.encode(to: encoder)
            case let .chatBskyGroupDefsInvalidJoinLinkPreviewView(value):
                try container.encode("chat.bsky.group.defs#invalidJoinLinkPreviewView", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .chatBskyGroupDefsJoinLinkPreviewView(value):
                hasher.combine("chat.bsky.group.defs#joinLinkPreviewView")
                hasher.combine(value)
            case let .chatBskyGroupDefsDisabledJoinLinkPreviewView(value):
                hasher.combine("chat.bsky.group.defs#disabledJoinLinkPreviewView")
                hasher.combine(value)
            case let .chatBskyGroupDefsInvalidJoinLinkPreviewView(value):
                hasher.combine("chat.bsky.group.defs#invalidJoinLinkPreviewView")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: OutputJoinLinkPreviewsUnion, rhs: OutputJoinLinkPreviewsUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .chatBskyGroupDefsJoinLinkPreviewView(lhsValue),
                .chatBskyGroupDefsJoinLinkPreviewView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyGroupDefsDisabledJoinLinkPreviewView(lhsValue),
                .chatBskyGroupDefsDisabledJoinLinkPreviewView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .chatBskyGroupDefsInvalidJoinLinkPreviewView(lhsValue),
                .chatBskyGroupDefsInvalidJoinLinkPreviewView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? OutputJoinLinkPreviewsUnion else { return false }
            return self == other
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .chatBskyGroupDefsJoinLinkPreviewView(value):
                map = map.adding(key: "$type", value: "chat.bsky.group.defs#joinLinkPreviewView")

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
            case let .chatBskyGroupDefsDisabledJoinLinkPreviewView(value):
                map = map.adding(key: "$type", value: "chat.bsky.group.defs#disabledJoinLinkPreviewView")

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
            case let .chatBskyGroupDefsInvalidJoinLinkPreviewView(value):
                map = map.adding(key: "$type", value: "chat.bsky.group.defs#invalidJoinLinkPreviewView")

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

public extension ATProtoClient.Chat.Bsky.Group {
    // MARK: - getJoinLinkPreviews

    /// Get public information about groups from join links. The output array matches the input codes one-to-one by position (and each view also carries its 'code'). Disabled codes return a disabledJoinLinkPreviewView, and codes that do not map to a previewable link return an invalidJoinLinkPreviewView.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getJoinLinkPreviews(input: ChatBskyGroupGetJoinLinkPreviews.Parameters) async throws -> (responseCode: Int, data: ChatBskyGroupGetJoinLinkPreviews.Output?) {
        let endpoint = "chat.bsky.group.getJoinLinkPreviews"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "chat.bsky.group.getJoinLinkPreviews")
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
                let decodedData = try decoder.decode(ChatBskyGroupGetJoinLinkPreviews.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.group.getJoinLinkPreviews: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
