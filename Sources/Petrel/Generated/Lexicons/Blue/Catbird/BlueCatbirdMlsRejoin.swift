import Foundation

// lexicon: 1, id: blue.catbird.mls.rejoin

public enum BlueCatbirdMlsRejoin {
    public static let typeIdentifier = "blue.catbird.mls.rejoin"
    public struct Input: ATProtocolCodable {
        public let convoId: String
        public let keyPackage: String
        public let reason: String?

        /// Standard public initializer
        public init(convoId: String, keyPackage: String, reason: String? = nil) {
            self.convoId = convoId
            self.keyPackage = keyPackage
            self.reason = reason
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            convoId = try container.decode(String.self, forKey: .convoId)

            keyPackage = try container.decode(String.self, forKey: .keyPackage)

            reason = try container.decodeIfPresent(String.self, forKey: .reason)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(convoId, forKey: .convoId)

            try container.encode(keyPackage, forKey: .keyPackage)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(reason, forKey: .reason)
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case keyPackage
            case reason
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)

            let keyPackageValue = try keyPackage.toCBORValue()
            map = map.adding(key: "keyPackage", value: keyPackageValue)

            if let value = reason {
                // Encode optional property even if it's an empty array for CBOR
                let reasonValue = try value.toCBORValue()
                map = map.adding(key: "reason", value: reasonValue)
            }

            return map
        }
    }

    public struct Output: ATProtocolCodable {
        public let requestId: String

        public let pending: Bool

        public let approvedAt: ATProtocolDate?

        /// Standard public initializer
        public init(
            requestId: String,

            pending: Bool,

            approvedAt: ATProtocolDate? = nil

        ) {
            self.requestId = requestId

            self.pending = pending

            self.approvedAt = approvedAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            requestId = try container.decode(String.self, forKey: .requestId)

            pending = try container.decode(Bool.self, forKey: .pending)

            approvedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .approvedAt)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(requestId, forKey: .requestId)

            try container.encode(pending, forKey: .pending)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(approvedAt, forKey: .approvedAt)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let requestIdValue = try requestId.toCBORValue()
            map = map.adding(key: "requestId", value: requestIdValue)

            let pendingValue = try pending.toCBORValue()
            map = map.adding(key: "pending", value: pendingValue)

            if let value = approvedAt {
                // Encode optional property even if it's an empty array for CBOR
                let approvedAtValue = try value.toCBORValue()
                map = map.adding(key: "approvedAt", value: approvedAtValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case requestId
            case pending
            case approvedAt
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case convoNotFound = "ConvoNotFound.Conversation not found or user was never a member"
        case alreadyMember = "AlreadyMember.User is already an active member with valid group state"
        case invalidKeyPackage = "InvalidKeyPackage.KeyPackage is malformed, expired, or invalid"
        case rateLimitExceeded = "RateLimitExceeded.Too many rejoin requests in short period"
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
    // MARK: - rejoin

    /// Request to rejoin an MLS conversation after local state loss. When a device registers and gets auto_joined_convos, it needs to request rejoin to get Welcome messages for those conversations.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func rejoin(
        input: BlueCatbirdMlsRejoin.Input

    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsRejoin.Output?) {
        let endpoint = "blue.catbird.mls.rejoin"

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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.rejoin")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsRejoin.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.rejoin: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
