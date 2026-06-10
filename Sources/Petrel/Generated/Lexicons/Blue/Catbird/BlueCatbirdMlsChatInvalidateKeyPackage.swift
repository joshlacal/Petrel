import Foundation

// lexicon: 1, id: blue.catbird.mlsChat.invalidateKeyPackage

public enum BlueCatbirdMlsChatInvalidateKeyPackage {
    public static let typeIdentifier = "blue.catbird.mlsChat.invalidateKeyPackage"
    public struct Input: ATProtocolCodable {
        public let deviceDid: DID
        public let keyPackageHash: String
        public let reason: String

        /// Standard public initializer
        public init(deviceDid: DID, keyPackageHash: String, reason: String) {
            self.deviceDid = deviceDid
            self.keyPackageHash = keyPackageHash
            self.reason = reason
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            deviceDid = try container.decode(DID.self, forKey: .deviceDid)
            keyPackageHash = try container.decode(String.self, forKey: .keyPackageHash)
            reason = try container.decode(String.self, forKey: .reason)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(deviceDid, forKey: .deviceDid)
            try container.encode(keyPackageHash, forKey: .keyPackageHash)
            try container.encode(reason, forKey: .reason)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let deviceDidValue = try deviceDid.toCBORValue()
            map = map.adding(key: "deviceDid", value: deviceDidValue)
            let keyPackageHashValue = try keyPackageHash.toCBORValue()
            map = map.adding(key: "keyPackageHash", value: keyPackageHashValue)
            let reasonValue = try reason.toCBORValue()
            map = map.adding(key: "reason", value: reasonValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case deviceDid
            case keyPackageHash
            case reason
        }
    }

    public struct Output: ATProtocolCodable {
        public let marked: Bool

        public let alreadyDead: Bool

        /// Standard public initializer
        public init(
            marked: Bool,

            alreadyDead: Bool

        ) {
            self.marked = marked

            self.alreadyDead = alreadyDead
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            marked = try container.decode(Bool.self, forKey: .marked)

            alreadyDead = try container.decode(Bool.self, forKey: .alreadyDead)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(marked, forKey: .marked)

            try container.encode(alreadyDead, forKey: .alreadyDead)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let markedValue = try marked.toCBORValue()
            map = map.adding(key: "marked", value: markedValue)

            let alreadyDeadValue = try alreadyDead.toCBORValue()
            map = map.adding(key: "alreadyDead", value: alreadyDeadValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case marked
            case alreadyDead
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case keyPackageNotFound = "KeyPackageNotFound.No KP exists for the given (deviceDid, keyPackageHash) pair."
        case unauthorized = "Unauthorized.Caller is neither the KP owner nor a member of any convo where the failure was observed."
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
    // MARK: - invalidateKeyPackage

    // Mark a server-stored KP as dead so the next getKeyPackages call for that DID will not select it. Underlying-KP equivalent of invalidateWelcome.
    //
    // - Parameter input: The input parameters for the request

    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func invalidateKeyPackage(
        input: BlueCatbirdMlsChatInvalidateKeyPackage.Input

    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatInvalidateKeyPackage.Output?) {
        let endpoint = "blue.catbird.mlsChat.invalidateKeyPackage"

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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.invalidateKeyPackage")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsChatInvalidateKeyPackage.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.invalidateKeyPackage: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
