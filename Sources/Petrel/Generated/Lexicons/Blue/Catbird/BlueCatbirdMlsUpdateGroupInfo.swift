import Foundation

// lexicon: 1, id: blue.catbird.mls.updateGroupInfo

public enum BlueCatbirdMlsUpdateGroupInfo {
    public static let typeIdentifier = "blue.catbird.mls.updateGroupInfo"
    public struct Input: ATProtocolCodable {
        public let convoId: String
        public let groupInfo: String
        public let epoch: Int

        /// Standard public initializer
        public init(convoId: String, groupInfo: String, epoch: Int) {
            self.convoId = convoId
            self.groupInfo = groupInfo
            self.epoch = epoch
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            convoId = try container.decode(String.self, forKey: .convoId)
            groupInfo = try container.decode(String.self, forKey: .groupInfo)
            epoch = try container.decode(Int.self, forKey: .epoch)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(groupInfo, forKey: .groupInfo)
            try container.encode(epoch, forKey: .epoch)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let groupInfoValue = try groupInfo.toCBORValue()
            map = map.adding(key: "groupInfo", value: groupInfoValue)
            let epochValue = try epoch.toCBORValue()
            map = map.adding(key: "epoch", value: epochValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case groupInfo
            case epoch
        }
    }

    public struct Output: ATProtocolCodable {
        public let updated: Bool

        /// Standard public initializer
        public init(
            updated: Bool

        ) {
            self.updated = updated
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            updated = try container.decode(Bool.self, forKey: .updated)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(updated, forKey: .updated)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let updatedValue = try updated.toCBORValue()
            map = map.adding(key: "updated", value: updatedValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case updated
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case unauthorized = "Unauthorized."
        case invalidGroupInfo = "InvalidGroupInfo."
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
    // MARK: - updateGroupInfo

    /// Update the cached GroupInfo for a conversation. Should be called by clients after committing a group state change.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func updateGroupInfo(
        input: BlueCatbirdMlsUpdateGroupInfo.Input

    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsUpdateGroupInfo.Output?) {
        let endpoint = "blue.catbird.mls.updateGroupInfo"

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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.updateGroupInfo")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsUpdateGroupInfo.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.updateGroupInfo: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
