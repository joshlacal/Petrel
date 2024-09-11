import Foundation
internal import ZippyJSON

// lexicon: 1, id: chat.bsky.convo.updateRead

public enum ChatBskyConvoUpdateRead {
    public static let typeIdentifier = "chat.bsky.convo.updateRead"
    public struct Input: ATProtocolCodable {
        public let convoId: String
        public let messageId: String?

        // Standard public initializer
        public init(convoId: String, messageId: String? = nil) {
            self.convoId = convoId
            self.messageId = messageId
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
    func updateRead(
        input: ChatBskyConvoUpdateRead.Input,

        duringInitialSetup: Bool = false
    ) async throws -> (responseCode: Int, data: ChatBskyConvoUpdateRead.Output?) {
        let endpoint = "/chat.bsky.convo.updateRead"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: requestData,
            queryItems: nil
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: duringInitialSetup)
        let responseCode = response.statusCode

        let decodedData = try? ZippyJSONDecoder().decode(ChatBskyConvoUpdateRead.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
