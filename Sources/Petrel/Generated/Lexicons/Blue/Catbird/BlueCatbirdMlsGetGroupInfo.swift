import Foundation

// lexicon: 1, id: blue.catbird.mls.getGroupInfo

public enum BlueCatbirdMlsGetGroupInfo {
    public static let typeIdentifier = "blue.catbird.mls.getGroupInfo"
    public struct Parameters: Parametrizable {
        public let convoId: String

        public init(
            convoId: String
        ) {
            self.convoId = convoId
        }
    }

    public struct Output: ATProtocolCodable {
        public let groupInfo: String

        public let epoch: Int

        public let expiresAt: ATProtocolDate?

        /// Standard public initializer
        public init(
            groupInfo: String,

            epoch: Int,

            expiresAt: ATProtocolDate? = nil

        ) {
            self.groupInfo = groupInfo

            self.epoch = epoch

            self.expiresAt = expiresAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            groupInfo = try container.decode(String.self, forKey: .groupInfo)

            epoch = try container.decode(Int.self, forKey: .epoch)

            expiresAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .expiresAt)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(groupInfo, forKey: .groupInfo)

            try container.encode(epoch, forKey: .epoch)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let groupInfoValue = try groupInfo.toCBORValue()
            map = map.adding(key: "groupInfo", value: groupInfoValue)

            let epochValue = try epoch.toCBORValue()
            map = map.adding(key: "epoch", value: epochValue)

            if let value = expiresAt {
                // Encode optional property even if it's an empty array for CBOR
                let expiresAtValue = try value.toCBORValue()
                map = map.adding(key: "expiresAt", value: expiresAtValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case groupInfo
            case epoch
            case expiresAt
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case notFound = "NotFound.Conversation not found"
        case unauthorized = "Unauthorized.Not a current or past member"
        case groupInfoUnavailable = "GroupInfoUnavailable.GroupInfo not yet generated for this conversation"
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
    // MARK: - getGroupInfo

    /// Fetch GroupInfo for external commit. Only available to current/past members.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getGroupInfo(input: BlueCatbirdMlsGetGroupInfo.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsGetGroupInfo.Output?) {
        let endpoint = "blue.catbird.mls.getGroupInfo"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.getGroupInfo")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsGetGroupInfo.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.getGroupInfo: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
