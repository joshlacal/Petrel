import Foundation

// lexicon: 1, id: chat.bsky.moderation.getConvos

public enum ChatBskyModerationGetConvos {
    public static let typeIdentifier = "chat.bsky.moderation.getConvos"
    public struct Parameters: Parametrizable {
        public let convoIds: [String]

        public init(
            convoIds: [String]
        ) {
            self.convoIds = convoIds
        }
    }

    public struct Output: ATProtocolCodable {
        public let convos: [ChatBskyModerationDefs.ConvoView]

        /// Standard public initializer
        public init(
            convos: [ChatBskyModerationDefs.ConvoView]

        ) {
            self.convos = convos
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            convos = try container.decode([ChatBskyModerationDefs.ConvoView].self, forKey: .convos)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(convos, forKey: .convos)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let convosValue = try convos.toCBORValue()
            map = map.adding(key: "convos", value: convosValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convos
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Moderation {
    // MARK: - getConvos

    /// [NOTE: This is under active development and should be considered unstable while this note is here]. Gets existing conversations by their IDs, for moderation purposes. Does not require the requester to be a member of the conversations. Unknown IDs are silently omitted from the response.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getConvos(input: ChatBskyModerationGetConvos.Parameters) async throws -> (responseCode: Int, data: ChatBskyModerationGetConvos.Output?) {
        let endpoint = "chat.bsky.moderation.getConvos"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "chat.bsky.moderation.getConvos")
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
                let decodedData = try decoder.decode(ChatBskyModerationGetConvos.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.moderation.getConvos: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
