import Foundation
internal import ZippyJSON

// lexicon: 1, id: chat.bsky.actor.deleteAccount

public enum ChatBskyActorDeleteAccount {
    public static let typeIdentifier = "chat.bsky.actor.deleteAccount"

    public struct Output: ATProtocolCodable {
        // Standard public initializer
        public init() {}
    }
}

public extension ATProtoClient.Chat.Bsky.Actor {
    ///
    func deleteAccount(
        duringInitialSetup: Bool = false
    ) async throws -> (responseCode: Int, data: ChatBskyActorDeleteAccount.Output?) {
        let endpoint = "/chat.bsky.actor.deleteAccount"

        let requestData: Data? = nil
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: requestData,
            queryItems: nil
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: duringInitialSetup)
        let responseCode = response.statusCode

        let decodedData = try? ZippyJSONDecoder().decode(ChatBskyActorDeleteAccount.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
