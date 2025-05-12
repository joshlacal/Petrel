import Foundation

// lexicon: 1, id: chat.bsky.convo.acceptConvo

public enum ChatBskyConvoAcceptConvo {
    public static let typeIdentifier = "chat.bsky.convo.acceptConvo"
    public struct Input: ATProtocolCodable {
        public let convoId: String

        // Standard public initializer
        public init(convoId: String) {
            self.convoId = convoId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            convoId = try container.decode(String.self, forKey: .convoId)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(convoId, forKey: .convoId)
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)

            return map
        }
    }

    public struct Output: ATProtocolCodable {
        public let rev: String?

        // Standard public initializer
        public init(
            rev: String? = nil

        ) {
            self.rev = rev
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            rev = try container.decodeIfPresent(String.self, forKey: .rev)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(rev, forKey: .rev)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = rev {
                // Encode optional property even if it's an empty array for CBOR
                let revValue = try value.toCBORValue()
                map = map.adding(key: "rev", value: revValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case rev
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Convo {
    // MARK: - acceptConvo

    ///
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func acceptConvo(
        input: ChatBskyConvoAcceptConvo.Input

    ) async throws -> (responseCode: Int, data: ChatBskyConvoAcceptConvo.Output?) {
        let endpoint = "chat.bsky.convo.acceptConvo"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
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
        let decodedData = try? decoder.decode(ChatBskyConvoAcceptConvo.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
