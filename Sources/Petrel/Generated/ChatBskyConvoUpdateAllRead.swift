import Foundation

// lexicon: 1, id: chat.bsky.convo.updateAllRead

public enum ChatBskyConvoUpdateAllRead {
    public static let typeIdentifier = "chat.bsky.convo.updateAllRead"
    public struct Input: ATProtocolCodable {
        public let status: String?

        // Standard public initializer
        public init(status: String? = nil) {
            self.status = status
        }
    }

    public struct Output: ATProtocolCodable {
        public let updatedCount: Int

        // Standard public initializer
        public init(
            updatedCount: Int

        ) {
            self.updatedCount = updatedCount
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Convo {
    ///
    func updateAllRead(
        input: ChatBskyConvoUpdateAllRead.Input

    ) async throws -> (responseCode: Int, data: ChatBskyConvoUpdateAllRead.Output?) {
        let endpoint = "chat.bsky.convo.updateAllRead"

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
        let decodedData = try? decoder.decode(ChatBskyConvoUpdateAllRead.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
