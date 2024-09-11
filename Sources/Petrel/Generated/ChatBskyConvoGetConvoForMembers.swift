import Foundation
internal import ZippyJSON

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
        let endpoint = "/chat.bsky.convo.getConvoForMembers"

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
        let decodedData = try? decoder.decode(ChatBskyConvoGetConvoForMembers.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
