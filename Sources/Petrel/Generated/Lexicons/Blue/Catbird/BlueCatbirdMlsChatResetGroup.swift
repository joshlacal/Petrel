import Foundation

// lexicon: 1, id: blue.catbird.mlsChat.resetGroup

public enum BlueCatbirdMlsChatResetGroup {
    public static let typeIdentifier = "blue.catbird.mlsChat.resetGroup"
    public struct Input: ATProtocolCodable {
        public let convoId: String
        public let newGroupId: String
        public let cipherSuite: String
        public let groupInfo: Bytes?
        public let reason: String?

        /// Standard public initializer
        public init(convoId: String, newGroupId: String, cipherSuite: String, groupInfo: Bytes? = nil, reason: String? = nil) {
            self.convoId = convoId
            self.newGroupId = newGroupId
            self.cipherSuite = cipherSuite
            self.groupInfo = groupInfo
            self.reason = reason
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            convoId = try container.decode(String.self, forKey: .convoId)
            newGroupId = try container.decode(String.self, forKey: .newGroupId)
            cipherSuite = try container.decode(String.self, forKey: .cipherSuite)
            groupInfo = try container.decodeIfPresent(Bytes.self, forKey: .groupInfo)
            reason = try container.decodeIfPresent(String.self, forKey: .reason)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(newGroupId, forKey: .newGroupId)
            try container.encode(cipherSuite, forKey: .cipherSuite)
            try container.encodeIfPresent(groupInfo, forKey: .groupInfo)
            try container.encodeIfPresent(reason, forKey: .reason)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let newGroupIdValue = try newGroupId.toCBORValue()
            map = map.adding(key: "newGroupId", value: newGroupIdValue)
            let cipherSuiteValue = try cipherSuite.toCBORValue()
            map = map.adding(key: "cipherSuite", value: cipherSuiteValue)
            if let value = groupInfo {
                let groupInfoValue = try value.toCBORValue()
                map = map.adding(key: "groupInfo", value: groupInfoValue)
            }
            if let value = reason {
                let reasonValue = try value.toCBORValue()
                map = map.adding(key: "reason", value: reasonValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case newGroupId
            case cipherSuite
            case groupInfo
            case reason
        }
    }

    public struct Output: ATProtocolCodable {
        public let success: Bool

        public let newGroupId: String

        public let resetGeneration: Int

        public let newEpoch: Int

        /// Standard public initializer
        public init(
            success: Bool,

            newGroupId: String,

            resetGeneration: Int,

            newEpoch: Int

        ) {
            self.success = success

            self.newGroupId = newGroupId

            self.resetGeneration = resetGeneration

            self.newEpoch = newEpoch
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            success = try container.decode(Bool.self, forKey: .success)

            newGroupId = try container.decode(String.self, forKey: .newGroupId)

            resetGeneration = try container.decode(Int.self, forKey: .resetGeneration)

            newEpoch = try container.decode(Int.self, forKey: .newEpoch)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(success, forKey: .success)

            try container.encode(newGroupId, forKey: .newGroupId)

            try container.encode(resetGeneration, forKey: .resetGeneration)

            try container.encode(newEpoch, forKey: .newEpoch)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let successValue = try success.toCBORValue()
            map = map.adding(key: "success", value: successValue)

            let newGroupIdValue = try newGroupId.toCBORValue()
            map = map.adding(key: "newGroupId", value: newGroupIdValue)

            let resetGenerationValue = try resetGeneration.toCBORValue()
            map = map.adding(key: "resetGeneration", value: resetGenerationValue)

            let newEpochValue = try newEpoch.toCBORValue()
            map = map.adding(key: "newEpoch", value: newEpochValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case success
            case newGroupId
            case resetGeneration
            case newEpoch
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case convoNotFound = "ConvoNotFound.Conversation not found"
        case notAdmin = "NotAdmin.Caller is not an admin of the conversation"
        case groupIdAlreadyExists = "GroupIdAlreadyExists.The new group ID is already in use by another conversation"
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
    // MARK: - resetGroup

    // Reset an MLS group by replacing its group ID and clearing ephemeral state Reset an MLS group for a conversation. Only admins may reset a group. This increments the reset count, swaps the group ID, resets the epoch to 0, and clears welcome messages and pending device additions.
    //
    // - Parameter input: The input parameters for the request

    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func resetGroup(
        input: BlueCatbirdMlsChatResetGroup.Input

    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatResetGroup.Output?) {
        let endpoint = "blue.catbird.mlsChat.resetGroup"

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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.resetGroup")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsChatResetGroup.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.resetGroup: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
