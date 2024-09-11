import Foundation
internal import ZippyJSON

// lexicon: 1, id: chat.bsky.convo.muteConvo

public enum ChatBskyConvoMuteConvo {
    public static let typeIdentifier = "chat.bsky.convo.muteConvo"
    public struct Input: ATProtocolCodable {
        public let convoId: String

        // Standard public initializer
        public init(convoId: String) {
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
    func muteConvo(
        input: ChatBskyConvoMuteConvo.Input,

        duringInitialSetup: Bool = false
    ) async throws -> (responseCode: Int, data: ChatBskyConvoMuteConvo.Output?) {
        let endpoint = "/chat.bsky.convo.muteConvo"

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

        let decodedData = try? ZippyJSONDecoder().decode(ChatBskyConvoMuteConvo.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
