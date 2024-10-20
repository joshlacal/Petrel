import Foundation
import ZippyJSON

// lexicon: 1, id: com.atproto.server.activateAccount

public enum ComAtprotoServerActivateAccount {
    public static let typeIdentifier = "com.atproto.server.activateAccount"
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Activates a currently deactivated account. Used to finalize account migration after the account's repo is imported and identity is setup.
    func activateAccount(
    ) async throws -> Int {
        let endpoint = "com.atproto.server.activateAccount"

        var headers: [String: String] = [:]

        let requestData: Data? = nil
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        let (_, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode
        return responseCode
    }
}
