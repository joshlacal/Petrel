import Foundation

// lexicon: 1, id: com.atproto.server.activateAccount

public enum ComAtprotoServerActivateAccount {
    public static let typeIdentifier = "com.atproto.server.activateAccount"
}

public extension ATProtoClient.Com.Atproto.Server {
    // MARK: - activateAccount

    /// Activates a currently deactivated account. Used to finalize account migration after the account's repo is imported and identity is setup.
    ///
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func activateAccount(
    ) async throws -> Int {
        let endpoint = "com.atproto.server.activateAccount"

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
