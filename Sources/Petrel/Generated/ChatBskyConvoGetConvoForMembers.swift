import Foundation
import ZippyJSON

// lexicon: 1, id: chat.bsky.convo.getConvoForMembers

public enum ChatBskyConvoGetConvoForMembers {
    public static let typeIdentifier = "chat.bsky.convo.getConvoForMembers"
    public struct Parameters: Parametrizable {
        public let members: [String]

        public init(
            members: [String]
        ) {
            self.members = members
        }
    }

    public struct Output: ATProtocolCodable {
        public let convo: ChatBskyConvoDefs.ConvoView

        // Standard public initializer
        public init(
            convo: ChatBskyConvoDefs.ConvoView

        ) {
            self.convo = convo
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Convo {
    ///
    func getConvoForMembers(input: ChatBskyConvoGetConvoForMembers.Parameters) async throws -> (responseCode: Int, data: ChatBskyConvoGetConvoForMembers.Output?) {
        let endpoint = "chat.bsky.convo.getConvoForMembers"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
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
        let decodedData = try? decoder.decode(ChatBskyConvoGetConvoForMembers.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
