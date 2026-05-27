import Foundation

// lexicon: 1, id: chat.bsky.convo.getConvoForMembers

public enum ChatBskyConvoGetConvoForMembers {
    public static let typeIdentifier = "chat.bsky.convo.getConvoForMembers"
    public struct Parameters: Parametrizable {
        public let members: [DID]

        public init(
            members: [DID]
        ) {
            self.members = members
        }
    }

    public struct Output: ATProtocolCodable {
        public let convo: ChatBskyConvoDefs.ConvoView

        /// Standard public initializer
        public init(
            convo: ChatBskyConvoDefs.ConvoView

        ) {
            self.convo = convo
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            convo = try container.decode(ChatBskyConvoDefs.ConvoView.self, forKey: .convo)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(convo, forKey: .convo)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let convoValue = try convo.toCBORValue()
            map = map.adding(key: "convo", value: convoValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convo
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case accountSuspended = "AccountSuspended."
        case blockedActor = "BlockedActor."
        case messagesDisabled = "MessagesDisabled."
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

public extension ATProtoClient.Chat.Bsky.Convo {
    // MARK: - getConvoForMembers

    /// Get or create a 1-1 conversation for the given members. Always returns the same direct (non-group) conversation. To create a group conversation, use createGroup.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getConvoForMembers(input: ChatBskyConvoGetConvoForMembers.Parameters) async throws -> (responseCode: Int, data: ChatBskyConvoGetConvoForMembers.Output?) {
        let endpoint = "chat.bsky.convo.getConvoForMembers"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "chat.bsky.convo.getConvoForMembers")
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
                let decodedData = try decoder.decode(ChatBskyConvoGetConvoForMembers.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.convo.getConvoForMembers: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
