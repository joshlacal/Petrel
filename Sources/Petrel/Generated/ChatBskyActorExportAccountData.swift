import Foundation
internal import ZippyJSON

// lexicon: 1, id: chat.bsky.actor.exportAccountData

public enum ChatBskyActorExportAccountData {
    public static let typeIdentifier = "chat.bsky.actor.exportAccountData"

    public struct Output: ATProtocolCodable {
        // Standard public initializer
        public init() {}
    }
}

public extension ATProtoClient.Chat.Bsky.Actor {
    ///
    func exportAccountData() async throws -> (responseCode: Int, data: ChatBskyActorExportAccountData.Output?) {
        let endpoint = "/chat.bsky.actor.exportAccountData"

        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: nil
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: false)
        let responseCode = response.statusCode

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ChatBskyActorExportAccountData.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
