import Foundation

// lexicon: 1, id: com.atproto.server.requestEmailUpdate

public enum ComAtprotoServerRequestEmailUpdate {
    public static let typeIdentifier = "com.atproto.server.requestEmailUpdate"

    public struct Output: ATProtocolCodable {
        public let tokenRequired: Bool

        /// Standard public initializer
        public init(
            tokenRequired: Bool

        ) {
            self.tokenRequired = tokenRequired
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            tokenRequired = try container.decode(Bool.self, forKey: .tokenRequired)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(tokenRequired, forKey: .tokenRequired)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let tokenRequiredValue = try tokenRequired.toCBORValue()
            map = map.adding(key: "tokenRequired", value: tokenRequiredValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case tokenRequired
        }
    }
}

public extension ATProtoClient.Com.Atproto.Server {
    // MARK: - requestEmailUpdate

    /// Request a token in order to update email.
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func requestEmailUpdate(
    ) async throws -> (responseCode: Int, data: ComAtprotoServerRequestEmailUpdate.Output?) {
        let endpoint = "com.atproto.server.requestEmailUpdate"

        var headers: [String: String] = [:]

        headers["Accept"] = "application/json"

        let requestData: Data? = nil
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.server.requestEmailUpdate")
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
                let decodedData = try decoder.decode(ComAtprotoServerRequestEmailUpdate.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.server.requestEmailUpdate: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
