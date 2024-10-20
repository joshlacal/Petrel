import Foundation
import ZippyJSON

// lexicon: 1, id: com.atproto.server.deleteSession

public enum ComAtprotoServerDeleteSession {
    public static let typeIdentifier = "com.atproto.server.deleteSession"
}

public extension ATProtoClient.Com.Atproto.Server {
    /// Delete the current session. Requires auth.
    func deleteSession(
    ) async throws -> Int {
        let endpoint = "com.atproto.server.deleteSession"

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
