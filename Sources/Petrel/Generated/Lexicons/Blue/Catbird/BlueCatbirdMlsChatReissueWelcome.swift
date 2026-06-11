import Foundation

// lexicon: 1, id: blue.catbird.mlsChat.reissueWelcome

public enum BlueCatbirdMlsChatReissueWelcome {
    public static let typeIdentifier = "blue.catbird.mlsChat.reissueWelcome"
    public struct Input: ATProtocolCodable {
        public let convoId: String
        public let recipientDeviceDid: DID
        public let reason: String

        /// Standard public initializer
        public init(convoId: String, recipientDeviceDid: DID, reason: String) {
            self.convoId = convoId
            self.recipientDeviceDid = recipientDeviceDid
            self.reason = reason
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            convoId = try container.decode(String.self, forKey: .convoId)
            recipientDeviceDid = try container.decode(DID.self, forKey: .recipientDeviceDid)
            reason = try container.decode(String.self, forKey: .reason)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(recipientDeviceDid, forKey: .recipientDeviceDid)
            try container.encode(reason, forKey: .reason)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let recipientDeviceDidValue = try recipientDeviceDid.toCBORValue()
            map = map.adding(key: "recipientDeviceDid", value: recipientDeviceDidValue)
            let reasonValue = try reason.toCBORValue()
            map = map.adding(key: "reason", value: reasonValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case recipientDeviceDid
            case reason
        }
    }

    public struct Output: ATProtocolCodable {
        public let welcomeRequested: Bool

        public let requestedAt: ATProtocolDate

        public let inviterDevice: DID?

        /// Standard public initializer
        public init(
            welcomeRequested: Bool,

            requestedAt: ATProtocolDate,

            inviterDevice: DID? = nil

        ) {
            self.welcomeRequested = welcomeRequested

            self.requestedAt = requestedAt

            self.inviterDevice = inviterDevice
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            welcomeRequested = try container.decode(Bool.self, forKey: .welcomeRequested)

            requestedAt = try container.decode(ATProtocolDate.self, forKey: .requestedAt)

            do {
                inviterDevice = try container.decodeIfPresent(DID.self, forKey: .inviterDevice)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'inviterDevice' — degrading to nil: \(error)")
                inviterDevice = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(welcomeRequested, forKey: .welcomeRequested)

            try container.encode(requestedAt, forKey: .requestedAt)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(inviterDevice, forKey: .inviterDevice)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let welcomeRequestedValue = try welcomeRequested.toCBORValue()
            map = map.adding(key: "welcomeRequested", value: welcomeRequestedValue)

            let requestedAtValue = try requestedAt.toCBORValue()
            map = map.adding(key: "requestedAt", value: requestedAtValue)

            if let value = inviterDevice {
                // Encode optional property even if it's an empty array for CBOR
                let inviterDeviceValue = try value.toCBORValue()
                map = map.adding(key: "inviterDevice", value: inviterDeviceValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case welcomeRequested
            case requestedAt
            case inviterDevice
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case convoNotFound = "ConvoNotFound.Conversation not found."
        case noAdminToReissue = "NoAdminToReissue.No current admin/inviter exists to ask. Recipient should Surrender."
        case rateLimited = "RateLimited.Exceeded 3 requests per (convo, recipient) per hour."
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
    // MARK: - reissueWelcome

    // Recipient device cannot decrypt the Welcome on this convo (NoMatchingKeyPackage). Server records the request and pushes a welcomeReissueRequest event to the inviter, who is expected to re-stage a new commit with a fresh KP. The recipient is told to wait. Rate limit: max 3 per (convo, recipient) per hour.
    //
    // - Parameter input: The input parameters for the request

    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func reissueWelcome(
        input: BlueCatbirdMlsChatReissueWelcome.Input

    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatReissueWelcome.Output?) {
        let endpoint = "blue.catbird.mlsChat.reissueWelcome"

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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.reissueWelcome")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsChatReissueWelcome.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.reissueWelcome: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
