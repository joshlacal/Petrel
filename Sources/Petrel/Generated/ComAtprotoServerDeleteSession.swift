import Foundation

// lexicon: 1, id: com.atproto.server.deleteSession

public enum ComAtprotoServerDeleteSession {
    public static let typeIdentifier = "com.atproto.server.deleteSession"
}

public extension ATProtoClient.Com.Atproto.Server {
    // MARK: - deleteSession

    /// Delete the current session. Requires auth.
    ///
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func deleteSession(
    ) async throws -> Int {
        let endpoint = "com.atproto.server.deleteSession"

        var headers: [String: String] = [:]

        let requestData: Data? = nil
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        let (_, response) = try await networkService.performRequest(urlRequest)

        let responseCode = response.statusCode
        return responseCode
    }
}
