import Foundation

// lexicon: 1, id: blue.catbird.mls.readdition

public enum BlueCatbirdMlsReaddition {
    public static let typeIdentifier = "blue.catbird.mls.readdition"
    public struct Input: ATProtocolCodable {
        public let convoId: String

        /// Standard public initializer
        public init(convoId: String) {
            self.convoId = convoId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            convoId = try container.decode(String.self, forKey: .convoId)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(convoId, forKey: .convoId)
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)

            return map
        }
    }

    public struct Output: ATProtocolCodable {
        public let requested: Bool

        public let activeMembers: Int?

        /// Standard public initializer
        public init(
            requested: Bool,

            activeMembers: Int? = nil

        ) {
            self.requested = requested

            self.activeMembers = activeMembers
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            requested = try container.decode(Bool.self, forKey: .requested)

            activeMembers = try container.decodeIfPresent(Int.self, forKey: .activeMembers)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(requested, forKey: .requested)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(activeMembers, forKey: .activeMembers)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let requestedValue = try requested.toCBORValue()
            map = map.adding(key: "requested", value: requestedValue)

            if let value = activeMembers {
                // Encode optional property even if it's an empty array for CBOR
                let activeMembersValue = try value.toCBORValue()
                map = map.adding(key: "activeMembers", value: activeMembersValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case requested
            case activeMembers
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case notFound = "NotFound.Conversation not found"
        case unauthorized = "Unauthorized.Not a member or past member of this conversation"
        case noActiveMembers = "NoActiveMembers.No active members available to process re-addition"
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
    // MARK: - readdition

    /// Request re-addition to a conversation when both Welcome and External Commit have failed. Active members will receive an SSE event and can re-add the user with fresh KeyPackages.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func readdition(
        input: BlueCatbirdMlsReaddition.Input

    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsReaddition.Output?) {
        let endpoint = "blue.catbird.mls.readdition"

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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.readdition")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsReaddition.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.readdition: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
