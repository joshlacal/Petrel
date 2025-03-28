import Foundation

// lexicon: 1, id: com.atproto.repo.importRepo

public enum ComAtprotoRepoImportRepo {
    public static let typeIdentifier = "com.atproto.repo.importRepo"
}

public extension ATProtoClient.Com.Atproto.Repo {
    /// Import a repo in the form of a CAR file. Requires Content-Length HTTP header to be set.
    func importRepo(
    ) async throws -> Int {
        let endpoint = "com.atproto.repo.importRepo"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/vnd.ipld.car"

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
