import Foundation

// lexicon: 1, id: blue.catbird.mlsChat.reconcileKeyPackages

public enum BlueCatbirdMlsChatReconcileKeyPackages {
    public static let typeIdentifier = "blue.catbird.mlsChat.reconcileKeyPackages"
    public struct Input: ATProtocolCodable {
        public let deviceId: String
        public let localHashes: [String]
        public let schemaVersion: Int

        /// Standard public initializer
        public init(deviceId: String, localHashes: [String], schemaVersion: Int) {
            self.deviceId = deviceId
            self.localHashes = localHashes
            self.schemaVersion = schemaVersion
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            deviceId = try container.decode(String.self, forKey: .deviceId)
            localHashes = try container.decode([String].self, forKey: .localHashes)
            schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(deviceId, forKey: .deviceId)
            try container.encode(localHashes, forKey: .localHashes)
            try container.encode(schemaVersion, forKey: .schemaVersion)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let deviceIdValue = try deviceId.toCBORValue()
            map = map.adding(key: "deviceId", value: deviceIdValue)
            let localHashesValue = try localHashes.toCBORValue()
            map = map.adding(key: "localHashes", value: localHashesValue)
            let schemaVersionValue = try schemaVersion.toCBORValue()
            map = map.adding(key: "schemaVersion", value: schemaVersionValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case deviceId
            case localHashes
            case schemaVersion
        }
    }

    public struct Output: ATProtocolCodable {
        public let serverOnly: [String]

        public let localOnly: [String]

        public let total: Int

        public let deviceVerified: Bool

        /// Standard public initializer
        public init(
            serverOnly: [String],

            localOnly: [String],

            total: Int,

            deviceVerified: Bool

        ) {
            self.serverOnly = serverOnly

            self.localOnly = localOnly

            self.total = total

            self.deviceVerified = deviceVerified
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            serverOnly = try container.decode([String].self, forKey: .serverOnly)

            localOnly = try container.decode([String].self, forKey: .localOnly)

            total = try container.decode(Int.self, forKey: .total)

            deviceVerified = try container.decode(Bool.self, forKey: .deviceVerified)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(serverOnly, forKey: .serverOnly)

            try container.encode(localOnly, forKey: .localOnly)

            try container.encode(total, forKey: .total)

            try container.encode(deviceVerified, forKey: .deviceVerified)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let serverOnlyValue = try serverOnly.toCBORValue()
            map = map.adding(key: "serverOnly", value: serverOnlyValue)

            let localOnlyValue = try localOnly.toCBORValue()
            map = map.adding(key: "localOnly", value: localOnlyValue)

            let totalValue = try total.toCBORValue()
            map = map.adding(key: "total", value: totalValue)

            let deviceVerifiedValue = try deviceVerified.toCBORValue()
            map = map.adding(key: "deviceVerified", value: deviceVerifiedValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case serverOnly
            case localOnly
            case total
            case deviceVerified
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case deviceNotFound = "DeviceNotFound.deviceId is not registered."
        case unauthorized = "Unauthorized.Caller is not the owner of deviceId."
        public var description: String {
            return rawValue
        }

        public var errorName: String {
            // Extract just the error name from the raw value
            let parts = rawValue.split(separator: ".")
            return String(parts.first ?? "")
        }
    }
}

public extension ATProtoClient.Blue.Catbird.MlsChat {
    // MARK: - reconcileKeyPackages

    // Bidirectional KP diff between client local store and server. Replaces publishKeyPackages action=sync for full reconciliation. Server returns BOTH directions of the diff (serverOnly + localOnly) and does NOT auto-delete on either side.
    //
    // - Parameter input: The input parameters for the request

    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func reconcileKeyPackages(
        input: BlueCatbirdMlsChatReconcileKeyPackages.Input

    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatReconcileKeyPackages.Output?) {
        let endpoint = "blue.catbird.mlsChat.reconcileKeyPackages"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)

        let queryItems: [URLQueryItem]? = nil

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.reconcileKeyPackages")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        // Only validate Content-Type and decode on success. Error responses
        // (4xx/5xx) may have missing or different Content-Type headers and
        // are handled by the caller via the status code.
        if (200 ... 299).contains(responseCode) {
            guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
                throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
            }

            if !contentType.lowercased().contains("application/json") {
                throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
            }

            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(BlueCatbirdMlsChatReconcileKeyPackages.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.reconcileKeyPackages: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
