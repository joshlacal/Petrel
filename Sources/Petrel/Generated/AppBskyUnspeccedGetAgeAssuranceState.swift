import Foundation

// lexicon: 1, id: app.bsky.unspecced.getAgeAssuranceState

public enum AppBskyUnspeccedGetAgeAssuranceState {
    public static let typeIdentifier = "app.bsky.unspecced.getAgeAssuranceState"
    public typealias Output = AppBskyUnspeccedDefs.AgeAssuranceState
}

public extension ATProtoClient.App.Bsky.Unspecced {
    // MARK: - getAgeAssuranceState

    /// Returns the current state of the age assurance process for an account. This is used to check if the user has completed age assurance or if further action is required.
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getAgeAssuranceState() async throws -> (responseCode: Int, data: AppBskyUnspeccedGetAgeAssuranceState.Output?) {
        let endpoint = "app.bsky.unspecced.getAgeAssuranceState"

        let queryItems: [URLQueryItem]? = nil

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)

        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyUnspeccedGetAgeAssuranceState.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
