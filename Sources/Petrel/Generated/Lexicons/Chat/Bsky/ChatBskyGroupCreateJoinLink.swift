import Foundation

// lexicon: 1, id: chat.bsky.group.createJoinLink

public enum ChatBskyGroupCreateJoinLink {
    public static let typeIdentifier = "chat.bsky.group.createJoinLink"
    public struct Input: ATProtocolCodable {
        public let convoId: String
        public let requireApproval: Bool?
        public let joinRule: ChatBskyGroupDefs.JoinRule

        /// Standard public initializer
        public init(convoId: String, requireApproval: Bool? = nil, joinRule: ChatBskyGroupDefs.JoinRule) {
            self.convoId = convoId
            self.requireApproval = requireApproval
            self.joinRule = joinRule
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            convoId = try container.decode(String.self, forKey: .convoId)
            requireApproval = try container.decodeIfPresent(Bool.self, forKey: .requireApproval)
            joinRule = try container.decode(ChatBskyGroupDefs.JoinRule.self, forKey: .joinRule)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(convoId, forKey: .convoId)
            try container.encodeIfPresent(requireApproval, forKey: .requireApproval)
            try container.encode(joinRule, forKey: .joinRule)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            if let value = requireApproval {
                let requireApprovalValue = try value.toCBORValue()
                map = map.adding(key: "requireApproval", value: requireApprovalValue)
            }
            let joinRuleValue = try joinRule.toCBORValue()
            map = map.adding(key: "joinRule", value: joinRuleValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case requireApproval
            case joinRule
        }
    }

    public struct Output: ATProtocolCodable {
        public let joinLink: ChatBskyGroupDefs.JoinLinkView

        /// Standard public initializer
        public init(
            joinLink: ChatBskyGroupDefs.JoinLinkView

        ) {
            self.joinLink = joinLink
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            joinLink = try container.decode(ChatBskyGroupDefs.JoinLinkView.self, forKey: .joinLink)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(joinLink, forKey: .joinLink)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let joinLinkValue = try joinLink.toCBORValue()
            map = map.adding(key: "joinLink", value: joinLinkValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case joinLink
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case enabledJoinLinkAlreadyExists = "EnabledJoinLinkAlreadyExists."
        case invalidConvo = "InvalidConvo."
        case insufficientRole = "InsufficientRole."
        public var description: String {
            return rawValue
        }

        public var errorName: String {
            // Extract just the error name from the raw value
            let parts = rawValue.split(separator: ".")
            return String(parts.first ?? "")
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Group {
    // MARK: - createJoinLink

    // Creates a join link for the group convo.
    //
    // - Parameter input: The input parameters for the request

    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func createJoinLink(
        input: ChatBskyGroupCreateJoinLink.Input

    ) async throws -> (responseCode: Int, data: ChatBskyGroupCreateJoinLink.Output?) {
        let endpoint = "chat.bsky.group.createJoinLink"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)

        let queryItems: [URLQueryItem]? = nil

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "chat.bsky.group.createJoinLink")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        // Only validate Content-Type and decode on success. Error responses
        // (4xx/5xx) may have missing or different Content-Type headers and
        // are handled by the caller via the status code.
        if (200 ... 299).contains(responseCode) {
            guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
                throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
            }

            if !contentType.lowercased().contains("application/json") {
                throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
            }

            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(ChatBskyGroupCreateJoinLink.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.group.createJoinLink: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
