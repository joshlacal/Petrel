import Foundation

// lexicon: 1, id: chat.bsky.convo.leaveConvo

public enum ChatBskyConvoLeaveConvo {
    public static let typeIdentifier = "chat.bsky.convo.leaveConvo"
    public struct Input: ATProtocolCodable {
        public let convoId: String

        // Standard public initializer
        public init(convoId: String) {
            self.convoId = convoId
        }
    }

    public struct Output: ATProtocolCodable {
        public let convoId: String

        public let rev: String

        // Standard public initializer
        public init(
            convoId: String,

            rev: String

        ) {
            self.convoId = convoId

            self.rev = rev
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Convo {
    ///
    func leaveConvo(
        input: ChatBskyConvoLeaveConvo.Input

    ) async throws -> (responseCode: Int, data: ChatBskyConvoLeaveConvo.Output?) {
        let endpoint = "chat.bsky.convo.leaveConvo"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode

        // Content-Type validation
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Data decoding and validation

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ChatBskyConvoLeaveConvo.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
