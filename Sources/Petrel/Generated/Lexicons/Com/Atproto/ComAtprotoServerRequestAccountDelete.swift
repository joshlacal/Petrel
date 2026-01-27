import Foundation

// lexicon: 1, id: com.atproto.server.requestAccountDelete

public enum ComAtprotoServerRequestAccountDelete {
    public static let typeIdentifier = "com.atproto.server.requestAccountDelete"
}

public extension ATProtoClient.Com.Atproto.Server {
    // MARK: - requestAccountDelete

    /// Initiate a user account deletion via email.
    ///
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func requestAccountDelete(
    ) async throws -> Int {
        let endpoint = "com.atproto.server.requestAccountDelete"

        var headers: [String: String] = [:]

        let requestData: Data? = nil
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.server.requestAccountDelete")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        return response.statusCode
    }
}
