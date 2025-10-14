import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// lexicon: 1, id: app.bsky.actor.putPreferences

public enum AppBskyActorPutPreferences {
    public static let typeIdentifier = "app.bsky.actor.putPreferences"
    public struct Input: ATProtocolCodable {
        public let preferences: AppBskyActorDefs.Preferences

        // Standard public initializer
        public init(preferences: AppBskyActorDefs.Preferences) {
            self.preferences = preferences
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            preferences = try container.decode(AppBskyActorDefs.Preferences.self, forKey: .preferences)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(preferences, forKey: .preferences)
        }

        private enum CodingKeys: String, CodingKey {
            case preferences
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let preferencesValue = try preferences.toCBORValue()
            map = map.adding(key: "preferences", value: preferencesValue)

            return map
        }
    }
}

public extension ATProtoClient.App.Bsky.Actor {
    // MARK: - putPreferences

    /// Set the private preferences attached to the account.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func putPreferences(
        input: AppBskyActorPutPreferences.Input

    ) async throws -> Int {
        let endpoint = "app.bsky.actor.putPreferences"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.actor.putPreferences")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        return responseCode
    }
}
