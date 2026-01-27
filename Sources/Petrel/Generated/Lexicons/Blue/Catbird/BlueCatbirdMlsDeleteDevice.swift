import Foundation

// lexicon: 1, id: blue.catbird.mls.deleteDevice

public enum BlueCatbirdMlsDeleteDevice {
    public static let typeIdentifier = "blue.catbird.mls.deleteDevice"
    public struct Input: ATProtocolCodable {
        public let deviceId: String

        /// Standard public initializer
        public init(deviceId: String) {
            self.deviceId = deviceId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            deviceId = try container.decode(String.self, forKey: .deviceId)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(deviceId, forKey: .deviceId)
        }

        private enum CodingKeys: String, CodingKey {
            case deviceId
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let deviceIdValue = try deviceId.toCBORValue()
            map = map.adding(key: "deviceId", value: deviceIdValue)

            return map
        }
    }

    public struct Output: ATProtocolCodable {
        public let deleted: Bool

        public let keyPackagesDeleted: Int

        /// Standard public initializer
        public init(
            deleted: Bool,

            keyPackagesDeleted: Int

        ) {
            self.deleted = deleted

            self.keyPackagesDeleted = keyPackagesDeleted
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            deleted = try container.decode(Bool.self, forKey: .deleted)

            keyPackagesDeleted = try container.decode(Int.self, forKey: .keyPackagesDeleted)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(deleted, forKey: .deleted)

            try container.encode(keyPackagesDeleted, forKey: .keyPackagesDeleted)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let deletedValue = try deleted.toCBORValue()
            map = map.adding(key: "deleted", value: deletedValue)

            let keyPackagesDeletedValue = try keyPackagesDeleted.toCBORValue()
            map = map.adding(key: "keyPackagesDeleted", value: keyPackagesDeletedValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case deleted
            case keyPackagesDeleted
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case deviceNotFound = "DeviceNotFound.The specified device does not exist"
        case unauthorized = "Unauthorized.User does not own this device or is not authenticated"
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

public extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - deleteDevice

    /// Delete a registered device and all its associated key packages. Users can only delete their own devices.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func deleteDevice(
        input: BlueCatbirdMlsDeleteDevice.Input

    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsDeleteDevice.Output?) {
        let endpoint = "blue.catbird.mls.deleteDevice"

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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.deleteDevice")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsDeleteDevice.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.deleteDevice: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
