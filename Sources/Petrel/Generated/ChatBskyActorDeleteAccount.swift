import Foundation

// lexicon: 1, id: chat.bsky.actor.deleteAccount

public enum ChatBskyActorDeleteAccount {
    public static let typeIdentifier = "chat.bsky.actor.deleteAccount"

    public struct Output: ATProtocolCodable {
        public let data: Data

        // Standard public initializer
        public init(
            data: Data

        ) {
            self.data = data
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Actor {
    ///
    func deleteAccount(
    ) async throws -> (responseCode: Int, data: ChatBskyActorDeleteAccount.Output?) {
        let endpoint = "chat.bsky.actor.deleteAccount"

        var headers: [String: String] = [:]

        headers["Accept"] = "application/json"

        let requestData: Data? = nil
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
        let decodedData = try? decoder.decode(ChatBskyActorDeleteAccount.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
