import Foundation

// lexicon: 1, id: app.bsky.unspecced.getConfig

public enum AppBskyUnspeccedGetConfig {
    public static let typeIdentifier = "app.bsky.unspecced.getConfig"

    public struct Output: ATProtocolCodable {
        public let checkEmailConfirmed: Bool?

        // Standard public initializer
        public init(
            checkEmailConfirmed: Bool? = nil

        ) {
            self.checkEmailConfirmed = checkEmailConfirmed
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            checkEmailConfirmed = try container.decodeIfPresent(Bool.self, forKey: .checkEmailConfirmed)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(checkEmailConfirmed, forKey: .checkEmailConfirmed)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = checkEmailConfirmed {
                // Encode optional property even if it's an empty array for CBOR

                let checkEmailConfirmedValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "checkEmailConfirmed", value: checkEmailConfirmedValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case checkEmailConfirmed
        }
    }
}

public extension ATProtoClient.App.Bsky.Unspecced {
    /// Get miscellaneous runtime configuration.
    func getConfig() async throws -> (responseCode: Int, data: AppBskyUnspeccedGetConfig.Output?) {
        let endpoint = "app.bsky.unspecced.getConfig"

        let queryItems: [URLQueryItem]? = nil

        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode

        // Content-Type validation
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Data decoding and validation

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyUnspeccedGetConfig.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
