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

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.actor.getProfile")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200 ... 299).contains(responseCode) {
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(AppBskyActorGetProfile.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.actor.getProfile: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
