import Foundation

// lexicon: 1, id: blue.catbird.mls.updateChatRequestSettings

public enum BlueCatbirdMlsUpdateChatRequestSettings {
    public static let typeIdentifier = "blue.catbird.mls.updateChatRequestSettings"
    public struct Input: ATProtocolCodable {
        public let allowFollowersBypass: Bool?
        public let allowFollowingBypass: Bool?
        public let autoExpireDays: Int?

        /// Standard public initializer
        public init(allowFollowersBypass: Bool? = nil, allowFollowingBypass: Bool? = nil, autoExpireDays: Int? = nil) {
            self.allowFollowersBypass = allowFollowersBypass
            self.allowFollowingBypass = allowFollowingBypass
            self.autoExpireDays = autoExpireDays
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            allowFollowersBypass = try container.decodeIfPresent(Bool.self, forKey: .allowFollowersBypass)

            allowFollowingBypass = try container.decodeIfPresent(Bool.self, forKey: .allowFollowingBypass)

            autoExpireDays = try container.decodeIfPresent(Int.self, forKey: .autoExpireDays)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(allowFollowersBypass, forKey: .allowFollowersBypass)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(allowFollowingBypass, forKey: .allowFollowingBypass)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(autoExpireDays, forKey: .autoExpireDays)
        }

        private enum CodingKeys: String, CodingKey {
            case allowFollowersBypass
            case allowFollowingBypass
            case autoExpireDays
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = allowFollowersBypass {
                // Encode optional property even if it's an empty array for CBOR
                let allowFollowersBypassValue = try value.toCBORValue()
                map = map.adding(key: "allowFollowersBypass", value: allowFollowersBypassValue)
            }

            if let value = allowFollowingBypass {
                // Encode optional property even if it's an empty array for CBOR
                let allowFollowingBypassValue = try value.toCBORValue()
                map = map.adding(key: "allowFollowingBypass", value: allowFollowingBypassValue)
            }

            if let value = autoExpireDays {
                // Encode optional property even if it's an empty array for CBOR
                let autoExpireDaysValue = try value.toCBORValue()
                map = map.adding(key: "autoExpireDays", value: autoExpireDaysValue)
            }

            return map
        }
    }

    public struct Output: ATProtocolCodable {
        public let allowFollowersBypass: Bool

        public let allowFollowingBypass: Bool

        public let autoExpireDays: Int

        /// Standard public initializer
        public init(
            allowFollowersBypass: Bool,

            allowFollowingBypass: Bool,

            autoExpireDays: Int

        ) {
            self.allowFollowersBypass = allowFollowersBypass

            self.allowFollowingBypass = allowFollowingBypass

            self.autoExpireDays = autoExpireDays
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            allowFollowersBypass = try container.decode(Bool.self, forKey: .allowFollowersBypass)

            allowFollowingBypass = try container.decode(Bool.self, forKey: .allowFollowingBypass)

            autoExpireDays = try container.decode(Int.self, forKey: .autoExpireDays)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(allowFollowersBypass, forKey: .allowFollowersBypass)

            try container.encode(allowFollowingBypass, forKey: .allowFollowingBypass)

            try container.encode(autoExpireDays, forKey: .autoExpireDays)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let allowFollowersBypassValue = try allowFollowersBypass.toCBORValue()
            map = map.adding(key: "allowFollowersBypass", value: allowFollowersBypassValue)

            let allowFollowingBypassValue = try allowFollowingBypass.toCBORValue()
            map = map.adding(key: "allowFollowingBypass", value: allowFollowingBypassValue)

            let autoExpireDaysValue = try autoExpireDays.toCBORValue()
            map = map.adding(key: "autoExpireDays", value: autoExpireDaysValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case allowFollowersBypass
            case allowFollowingBypass
            case autoExpireDays
        }
    }
}

public extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - updateChatRequestSettings

    /// Update user's chat request settings
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func updateChatRequestSettings(
        input: BlueCatbirdMlsUpdateChatRequestSettings.Input

    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsUpdateChatRequestSettings.Output?) {
        let endpoint = "blue.catbird.mls.updateChatRequestSettings"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.updateChatRequestSettings")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsUpdateChatRequestSettings.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.updateChatRequestSettings: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
