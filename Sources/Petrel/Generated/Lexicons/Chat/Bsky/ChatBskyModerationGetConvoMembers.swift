import Foundation

// lexicon: 1, id: chat.bsky.moderation.getConvoMembers

public enum ChatBskyModerationGetConvoMembers {
    public static let typeIdentifier = "chat.bsky.moderation.getConvoMembers"
    public struct Parameters: Parametrizable {
        public let convoId: String
        public let limit: Int?
        public let cursor: String?

        public init(
            convoId: String,
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.convoId = convoId
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let members: [ChatBskyActorDefs.ProfileViewBasic]

        /// Standard public initializer
        public init(
            cursor: String? = nil,

            members: [ChatBskyActorDefs.ProfileViewBasic]

        ) {
            self.cursor = cursor

            self.members = members
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

            members = try container.decode([ChatBskyActorDefs.ProfileViewBasic].self, forKey: .members)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(members, forKey: .members)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let membersValue = try members.toCBORValue()
            map = map.adding(key: "members", value: membersValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case members
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case invalidConvo = "InvalidConvo."
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

public extension ATProtoClient.Chat.Bsky.Moderation {
    // MARK: - getConvoMembers

    /// Returns a paginated list of members from a conversation, for moderation purposes. Does not require the requester to be a member of the conversation.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getConvoMembers(input: ChatBskyModerationGetConvoMembers.Parameters) async throws -> (responseCode: Int, data: ChatBskyModerationGetConvoMembers.Output?) {
        let endpoint = "chat.bsky.moderation.getConvoMembers"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "chat.bsky.moderation.getConvoMembers")
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
                let decodedData = try decoder.decode(ChatBskyModerationGetConvoMembers.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.moderation.getConvoMembers: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
