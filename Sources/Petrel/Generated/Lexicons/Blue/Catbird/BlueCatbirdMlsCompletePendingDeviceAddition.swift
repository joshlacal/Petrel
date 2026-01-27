import Foundation

// lexicon: 1, id: blue.catbird.mls.completePendingDeviceAddition

public enum BlueCatbirdMlsCompletePendingDeviceAddition {
    public static let typeIdentifier = "blue.catbird.mls.completePendingDeviceAddition"
    public struct Input: ATProtocolCodable {
        public let pendingAdditionId: String
        public let newEpoch: Int

        /// Standard public initializer
        public init(pendingAdditionId: String, newEpoch: Int) {
            self.pendingAdditionId = pendingAdditionId
            self.newEpoch = newEpoch
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            pendingAdditionId = try container.decode(String.self, forKey: .pendingAdditionId)
            newEpoch = try container.decode(Int.self, forKey: .newEpoch)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(pendingAdditionId, forKey: .pendingAdditionId)
            try container.encode(newEpoch, forKey: .newEpoch)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let pendingAdditionIdValue = try pendingAdditionId.toCBORValue()
            map = map.adding(key: "pendingAdditionId", value: pendingAdditionIdValue)
            let newEpochValue = try newEpoch.toCBORValue()
            map = map.adding(key: "newEpoch", value: newEpochValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case pendingAdditionId
            case newEpoch
        }
    }

    public struct Output: ATProtocolCodable {
        public let success: Bool

        public let error: String?

        /// Standard public initializer
        public init(
            success: Bool,

            error: String? = nil

        ) {
            self.success = success

            self.error = error
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            success = try container.decode(Bool.self, forKey: .success)

            error = try container.decodeIfPresent(String.self, forKey: .error)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(success, forKey: .success)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(error, forKey: .error)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let successValue = try success.toCBORValue()
            map = map.adding(key: "success", value: successValue)

            if let value = error {
                // Encode optional property even if it's an empty array for CBOR
                let errorValue = try value.toCBORValue()
                map = map.adding(key: "error", value: errorValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case success
            case error
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case notClaimed = "NotClaimed.Pending addition was not claimed by caller"
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
    // MARK: - completePendingDeviceAddition

    /// Mark a pending device addition as complete after successful addMembers Marks a claimed pending device addition as completed. Call this after successfully adding the device via addMembers. Returns success=false with error field if pending addition not found or in wrong state.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func completePendingDeviceAddition(
        input: BlueCatbirdMlsCompletePendingDeviceAddition.Input

    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsCompletePendingDeviceAddition.Output?) {
        let endpoint = "blue.catbird.mls.completePendingDeviceAddition"

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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.completePendingDeviceAddition")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsCompletePendingDeviceAddition.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.completePendingDeviceAddition: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
