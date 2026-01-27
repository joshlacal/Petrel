import Foundation

// lexicon: 1, id: blue.catbird.mls.declineChatRequest

public enum BlueCatbirdMlsDeclineChatRequest {
    public static let typeIdentifier = "blue.catbird.mls.declineChatRequest"
    public struct Input: ATProtocolCodable {
        public let requestId: String
        public let reportReason: String?
        public let reportDetails: String?

        /// Standard public initializer
        public init(requestId: String, reportReason: String? = nil, reportDetails: String? = nil) {
            self.requestId = requestId
            self.reportReason = reportReason
            self.reportDetails = reportDetails
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            requestId = try container.decode(String.self, forKey: .requestId)
            reportReason = try container.decodeIfPresent(String.self, forKey: .reportReason)
            reportDetails = try container.decodeIfPresent(String.self, forKey: .reportDetails)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(requestId, forKey: .requestId)
            try container.encodeIfPresent(reportReason, forKey: .reportReason)
            try container.encodeIfPresent(reportDetails, forKey: .reportDetails)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let requestIdValue = try requestId.toCBORValue()
            map = map.adding(key: "requestId", value: requestIdValue)
            if let value = reportReason {
                let reportReasonValue = try value.toCBORValue()
                map = map.adding(key: "reportReason", value: reportReasonValue)
            }
            if let value = reportDetails {
                let reportDetailsValue = try value.toCBORValue()
                map = map.adding(key: "reportDetails", value: reportDetailsValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case requestId
            case reportReason
            case reportDetails
        }
    }

    public struct Output: ATProtocolCodable {
        public let success: Bool

        /// Standard public initializer
        public init(
            success: Bool

        ) {
            self.success = success
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            success = try container.decode(Bool.self, forKey: .success)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(success, forKey: .success)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let successValue = try success.toCBORValue()
            map = map.adding(key: "success", value: successValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case success
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case requestNotFound = "RequestNotFound."
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
    // MARK: - declineChatRequest

    /// Decline a chat request
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func declineChatRequest(
        input: BlueCatbirdMlsDeclineChatRequest.Input

    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsDeclineChatRequest.Output?) {
        let endpoint = "blue.catbird.mls.declineChatRequest"

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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.declineChatRequest")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsDeclineChatRequest.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.declineChatRequest: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
