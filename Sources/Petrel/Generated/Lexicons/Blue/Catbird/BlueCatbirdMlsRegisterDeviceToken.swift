import Foundation

// lexicon: 1, id: blue.catbird.mls.registerDeviceToken

public enum BlueCatbirdMlsRegisterDeviceToken {
    public static let typeIdentifier = "blue.catbird.mls.registerDeviceToken"
    public struct Input: ATProtocolCodable {
        public let deviceId: String
        public let pushToken: String
        public let deviceName: String?
        public let platform: String?

        /// Standard public initializer
        public init(deviceId: String, pushToken: String, deviceName: String? = nil, platform: String? = nil) {
            self.deviceId = deviceId
            self.pushToken = pushToken
            self.deviceName = deviceName
            self.platform = platform
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            deviceId = try container.decode(String.self, forKey: .deviceId)

            pushToken = try container.decode(String.self, forKey: .pushToken)

            deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName)

            platform = try container.decodeIfPresent(String.self, forKey: .platform)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(deviceId, forKey: .deviceId)

            try container.encode(pushToken, forKey: .pushToken)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(deviceName, forKey: .deviceName)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(platform, forKey: .platform)
        }

        private enum CodingKeys: String, CodingKey {
            case deviceId
            case pushToken
            case deviceName
            case platform
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let deviceIdValue = try deviceId.toCBORValue()
            map = map.adding(key: "deviceId", value: deviceIdValue)

            let pushTokenValue = try pushToken.toCBORValue()
            map = map.adding(key: "pushToken", value: pushTokenValue)

            if let value = deviceName {
                // Encode optional property even if it's an empty array for CBOR
                let deviceNameValue = try value.toCBORValue()
                map = map.adding(key: "deviceName", value: deviceNameValue)
            }

            if let value = platform {
                // Encode optional property even if it's an empty array for CBOR
                let platformValue = try value.toCBORValue()
                map = map.adding(key: "platform", value: platformValue)
            }

            return map
        }
    }

    public struct Output: ATProtocolCodable {
        public let success: Bool

        /// Standard public initializer
        public init(
            success: Bool

        ) {
            self.success = success
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            success = try container.decode(Bool.self, forKey: .success)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(success, forKey: .success)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let successValue = try success.toCBORValue()
            map = map.adding(key: "success", value: successValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case success
        }
    }
}

public extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - registerDeviceToken

    /// Register or update a device push token for APNs.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func registerDeviceToken(
        input: BlueCatbirdMlsRegisterDeviceToken.Input

    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsRegisterDeviceToken.Output?) {
        let endpoint = "blue.catbird.mls.registerDeviceToken"

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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.registerDeviceToken")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsRegisterDeviceToken.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.registerDeviceToken: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
