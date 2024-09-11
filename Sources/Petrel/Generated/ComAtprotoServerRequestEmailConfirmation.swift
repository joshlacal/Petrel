import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.server.requestEmailConfirmation

public enum ComAtprotoServerRequestEmailConfirmation {
    public static let typeIdentifier = "com.atproto.server.requestEmailConfirmation"
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Request an email with a code to confirm ownership of email.
    func requestEmailConfirmation(
        duringInitialSetup: Bool = false
    ) async throws -> Int {
        let endpoint = "/com.atproto.server.requestEmailConfirmation"

        let requestData: Data? = nil
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: requestData,
            queryItems: nil
        )

        let (_, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: duringInitialSetup)
        let responseCode = response.statusCode

        return responseCode
    }
}
