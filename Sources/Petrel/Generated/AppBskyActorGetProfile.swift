import Foundation

// lexicon: 1, id: app.bsky.actor.getProfile

public enum AppBskyActorGetProfile {
    public static let typeIdentifier = "app.bsky.actor.getProfile"
    public struct Parameters: Parametrizable {
        public let actor: ATIdentifier

        public init(
            actor: ATIdentifier
        ) {
            self.actor = actor
        }
    }

    public typealias Output = AppBskyActorDefs.ProfileViewDetailed
}

public extension ATProtoClient.App.Bsky.Actor {
    // MARK: - getProfile

    /// Get detailed profile view of an actor. Does not require auth, but contains relevant metadata with auth.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getProfile(input: AppBskyActorGetProfile.Parameters) async throws -> (responseCode: Int, data: AppBskyActorGetProfile.Output?) {
        let endpoint = "app.bsky.actor.getProfile"

        let queryItems = input.asQueryItems()

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
        let decodedData = try? decoder.decode(AppBskyActorGetProfile.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
