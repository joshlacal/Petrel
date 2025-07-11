import Foundation

// lexicon: 1, id: app.bsky.unspecced.getConfig

public enum AppBskyUnspeccedGetConfig {
    public static let typeIdentifier = "app.bsky.unspecced.getConfig"

    public struct LiveNowConfig: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.unspecced.getConfig#liveNowConfig"
        public let did: DID
        public let domains: [String]

        // Standard initializer
        public init(
            did: DID, domains: [String]
        ) {
            self.did = did
            self.domains = domains
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                did = try container.decode(DID.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
            do {
                domains = try container.decode([String].self, forKey: .domains)

            } catch {
                LogManager.logError("Decoding error for property 'domains': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(did, forKey: .did)

            try container.encode(domains, forKey: .domains)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(domains)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if did != other.did {
                return false
            }

            if domains != other.domains {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)

            let domainsValue = try domains.toCBORValue()
            map = map.adding(key: "domains", value: domainsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case domains
        }
    }

    public struct Output: ATProtocolCodable {
        public let checkEmailConfirmed: Bool?

        public let liveNow: [LiveNowConfig]?

        // Standard public initializer
        public init(
            checkEmailConfirmed: Bool? = nil,

            liveNow: [LiveNowConfig]? = nil

        ) {
            self.checkEmailConfirmed = checkEmailConfirmed

            self.liveNow = liveNow
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            checkEmailConfirmed = try container.decodeIfPresent(Bool.self, forKey: .checkEmailConfirmed)

            liveNow = try container.decodeIfPresent([LiveNowConfig].self, forKey: .liveNow)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(checkEmailConfirmed, forKey: .checkEmailConfirmed)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(liveNow, forKey: .liveNow)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = checkEmailConfirmed {
                // Encode optional property even if it's an empty array for CBOR
                let checkEmailConfirmedValue = try value.toCBORValue()
                map = map.adding(key: "checkEmailConfirmed", value: checkEmailConfirmedValue)
            }

            if let value = liveNow {
                // Encode optional property even if it's an empty array for CBOR
                let liveNowValue = try value.toCBORValue()
                map = map.adding(key: "liveNow", value: liveNowValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case checkEmailConfirmed
            case liveNow
        }
    }
}

public extension ATProtoClient.App.Bsky.Unspecced {
    // MARK: - getConfig

    /// Get miscellaneous runtime configuration.
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getConfig() async throws -> (responseCode: Int, data: AppBskyUnspeccedGetConfig.Output?) {
        let endpoint = "app.bsky.unspecced.getConfig"

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
        let decodedData = try? decoder.decode(AppBskyUnspeccedGetConfig.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
