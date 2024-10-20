import Foundation
import ZippyJSON

// lexicon: 1, id: com.atproto.server.requestEmailConfirmation

public enum ComAtprotoServerRequestEmailConfirmation {
    public static let typeIdentifier = "com.atproto.server.requestEmailConfirmation"
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Request an email with a code to confirm ownership of email.
    func requestEmailConfirmation(
    ) async throws -> Int {
        let endpoint = "com.atproto.server.requestEmailConfirmation"

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
