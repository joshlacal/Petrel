import Foundation

// lexicon: 1, id: com.atproto.repo.importRepo

public enum ComAtprotoRepoImportRepo {
    public static let typeIdentifier = "com.atproto.repo.importRepo"
}

public extension ATProtoClient.Com.Atproto.Repo {
    // MARK: - importRepo

    /// Import a repo in the form of a CAR file. Requires Content-Length HTTP header to be set.
    ///
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func importRepo(
    ) async throws -> Int {
        let endpoint = "com.atproto.repo.importRepo"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/vnd.ipld.car"

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
