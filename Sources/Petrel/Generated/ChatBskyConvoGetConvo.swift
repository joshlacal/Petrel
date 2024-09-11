import Foundation
internal import ZippyJSON

// lexicon: 1, id: chat.bsky.convo.getConvo

public enum ChatBskyConvoGetConvo {
    public static let typeIdentifier = "chat.bsky.convo.getConvo"
    public struct Parameters: Parametrizable {
        public let convoId: String

        public init(
            convoId: String
        ) {
            self.convoId = convoId
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
    func getConvo(input: ChatBskyConvoGetConvo.Parameters) async throws -> (responseCode: Int, data: ChatBskyConvoGetConvo.Output?) {
        let endpoint = "/chat.bsky.convo.getConvo"

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
        let decodedData = try? decoder.decode(ChatBskyConvoGetConvo.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
