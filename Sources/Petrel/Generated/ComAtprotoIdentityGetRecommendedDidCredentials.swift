import Foundation

// lexicon: 1, id: com.atproto.identity.getRecommendedDidCredentials

public enum ComAtprotoIdentityGetRecommendedDidCredentials {
    public static let typeIdentifier = "com.atproto.identity.getRecommendedDidCredentials"

    public struct Output: ATProtocolCodable {
        public let rotationKeys: [String]?

        public let alsoKnownAs: [String]?

        public let verificationMethods: ATProtocolValueContainer?

        public let services: ATProtocolValueContainer?

        // Standard public initializer
        public init(
            rotationKeys: [String]? = nil,

            alsoKnownAs: [String]? = nil,

            verificationMethods: ATProtocolValueContainer? = nil,

            services: ATProtocolValueContainer? = nil

        ) {
            self.rotationKeys = rotationKeys

            self.alsoKnownAs = alsoKnownAs

            self.verificationMethods = verificationMethods

            self.services = services
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            rotationKeys = try container.decodeIfPresent([String].self, forKey: .rotationKeys)

            alsoKnownAs = try container.decodeIfPresent([String].self, forKey: .alsoKnownAs)

            verificationMethods = try container.decodeIfPresent(ATProtocolValueContainer.self, forKey: .verificationMethods)

            services = try container.decodeIfPresent(ATProtocolValueContainer.self, forKey: .services)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            if let value = rotationKeys {
                if !value.isEmpty {
                    try container.encode(value, forKey: .rotationKeys)
                }
            }

            if let value = alsoKnownAs {
                if !value.isEmpty {
                    try container.encode(value, forKey: .alsoKnownAs)
                }
            }

            if let value = verificationMethods {
                try container.encode(value, forKey: .verificationMethods)
            }

            if let value = services {
                try container.encode(value, forKey: .services)
            }
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            if let value = rotationKeys {
                if !value.isEmpty {
                    let rotationKeysValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                    map = map.adding(key: "rotationKeys", value: rotationKeysValue)
                }
            }

            if let value = alsoKnownAs {
                if !value.isEmpty {
                    let alsoKnownAsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                    map = map.adding(key: "alsoKnownAs", value: alsoKnownAsValue)
                }
            }

            if let value = verificationMethods {
                let verificationMethodsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "verificationMethods", value: verificationMethodsValue)
            }

            if let value = services {
                let servicesValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "services", value: servicesValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case rotationKeys
            case alsoKnownAs
            case verificationMethods
            case services
        }
    }
}

public extension ATProtoClient.Com.Atproto.Identity {
    /// Describe the credentials that should be included in the DID doc of an account that is migrating to this service.
    func getRecommendedDidCredentials() async throws -> (responseCode: Int, data: ComAtprotoIdentityGetRecommendedDidCredentials.Output?) {
        let endpoint = "com.atproto.identity.getRecommendedDidCredentials"

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
        let decodedData = try? decoder.decode(ComAtprotoIdentityGetRecommendedDidCredentials.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
