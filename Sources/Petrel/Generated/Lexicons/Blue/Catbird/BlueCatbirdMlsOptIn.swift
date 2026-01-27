import Foundation

// lexicon: 1, id: blue.catbird.mls.optIn

public enum BlueCatbirdMlsOptIn {
    public static let typeIdentifier = "blue.catbird.mls.optIn"
    public struct Input: ATProtocolCodable {
        public let deviceId: String?

        /// Standard public initializer
        public init(deviceId: String? = nil) {
            self.deviceId = deviceId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(deviceId, forKey: .deviceId)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            if let value = deviceId {
                let deviceIdValue = try value.toCBORValue()
                map = map.adding(key: "deviceId", value: deviceIdValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case deviceId
        }
    }

    public struct Output: ATProtocolCodable {
        public let optedIn: Bool

        public let optedInAt: ATProtocolDate

        /// Standard public initializer
        public init(
            optedIn: Bool,

            optedInAt: ATProtocolDate

        ) {
            self.optedIn = optedIn

            self.optedInAt = optedInAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            optedIn = try container.decode(Bool.self, forKey: .optedIn)

            optedInAt = try container.decode(ATProtocolDate.self, forKey: .optedInAt)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(optedIn, forKey: .optedIn)

            try container.encode(optedInAt, forKey: .optedInAt)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let optedInValue = try optedIn.toCBORValue()
            map = map.adding(key: "optedIn", value: optedInValue)

            let optedInAtValue = try optedInAt.toCBORValue()
            map = map.adding(key: "optedInAt", value: optedInAtValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case optedIn
            case optedInAt
        }
    }
}

public extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - optIn

    /// Opt in to MLS chat. Creates private server-side record.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func optIn(
        input: BlueCatbirdMlsOptIn.Input

    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsOptIn.Output?) {
        let endpoint = "blue.catbird.mls.optIn"

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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.optIn")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsOptIn.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.optIn: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
