import Foundation
internal import ZippyJSON

// lexicon: 1, id: chat.bsky.convo.listConvos

public enum ChatBskyConvoListConvos {
    public static let typeIdentifier = "chat.bsky.convo.listConvos"
    public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?

        public init(
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let convos: [ChatBskyConvoDefs.ConvoView]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            convos: [ChatBskyConvoDefs.ConvoView]
        ) {
            self.cursor = cursor

            self.convos = convos
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Convo {
    ///
    func listConvos(input: ChatBskyConvoListConvos.Parameters) async throws -> (responseCode: Int, data: ChatBskyConvoListConvos.Output?) {
        let endpoint = "/chat.bsky.convo.listConvos"

        let queryItems = input.asQueryItems()
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: false)
        let responseCode = response.statusCode

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ChatBskyConvoListConvos.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
