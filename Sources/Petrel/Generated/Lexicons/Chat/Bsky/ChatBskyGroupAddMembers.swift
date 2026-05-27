import Foundation

// lexicon: 1, id: chat.bsky.group.addMembers

public enum ChatBskyGroupAddMembers {
    public static let typeIdentifier = "chat.bsky.group.addMembers"
    public struct Input: ATProtocolCodable {
        public let convoId: String
        public let members: [DID]

        /// Standard public initializer
        public init(convoId: String, members: [DID]) {
            self.convoId = convoId
            self.members = members
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            convoId = try container.decode(String.self, forKey: .convoId)
            members = try container.decode([DID].self, forKey: .members)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(members, forKey: .members)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let membersValue = try members.toCBORValue()
            map = map.adding(key: "members", value: membersValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case members
        }
    }

    public struct Output: ATProtocolCodable {
        public let convo: ChatBskyConvoDefs.ConvoView

        public let addedMembers: [ChatBskyActorDefs.ProfileViewBasic]?

        /// Standard public initializer
        public init(
            convo: ChatBskyConvoDefs.ConvoView,

            addedMembers: [ChatBskyActorDefs.ProfileViewBasic]? = nil

        ) {
            self.convo = convo

            self.addedMembers = addedMembers
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            convo = try container.decode(ChatBskyConvoDefs.ConvoView.self, forKey: .convo)

            addedMembers = try container.decodeIfPresent([ChatBskyActorDefs.ProfileViewBasic].self, forKey: .addedMembers)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(convo, forKey: .convo)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(addedMembers, forKey: .addedMembers)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let convoValue = try convo.toCBORValue()
            map = map.adding(key: "convo", value: convoValue)

            if let value = addedMembers {
                // Encode optional property even if it's an empty array for CBOR
                let addedMembersValue = try value.toCBORValue()
                map = map.adding(key: "addedMembers", value: addedMembersValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convo
            case addedMembers
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case accountSuspended = "AccountSuspended."
        case blockedActor = "BlockedActor."
        case groupInvitesDisabled = "GroupInvitesDisabled."
        case convoLocked = "ConvoLocked."
        case insufficientRole = "InsufficientRole."
        case invalidConvo = "InvalidConvo."
        case memberLimitReached = "MemberLimitReached."
        case notFollowedBySender = "NotFollowedBySender."
        case recipientNotFound = "RecipientNotFound."
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
    // MARK: - addMembers

    // [NOTE: This is under active development and should be considered unstable while this note is here]. Adds members to a group. The members are added in 'request' status, so they have to accept it. This creates convo memberships.
    //
    // - Parameter input: The input parameters for the request

    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func addMembers(
        input: ChatBskyGroupAddMembers.Input

    ) async throws -> (responseCode: Int, data: ChatBskyGroupAddMembers.Output?) {
        let endpoint = "chat.bsky.group.addMembers"

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
        let serviceDID = await networkService.getServiceDID(for: "chat.bsky.group.addMembers")
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
                let decodedData = try decoder.decode(ChatBskyGroupAddMembers.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.group.addMembers: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
